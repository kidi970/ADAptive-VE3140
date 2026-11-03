"""Local fixtures and fake targets only; no USB imports or subprocesses run."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import diagnostic_guard as guard
import lamp_experiment as lamp
import sensor_experiment as sensor


def digest(data):
    return hashlib.sha256(data).hexdigest()


class DiagnosticGuardTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.image = self.root / 'diagnostic.elf'
        self.image.write_bytes(b'synthetic local image; never executable')
        self.sha = digest(self.image.read_bytes())
        self.probe = 'SYNTHETIC-PROBE'
        # Any forgotten process call fails the test before a process is started.
        self.process_guard = patch.object(subprocess, 'Popen', side_effect=AssertionError('subprocess forbidden'))
        self.process_guard.start()
        self.addCleanup(self.process_guard.stop)

    def backup(self):
        directory = self.root / 'backup'
        directory.mkdir()
        (directory / 'probe-id.txt').write_text(self.probe + '\n')
        sums = []
        for kind, size in (('flash', 0x80000), ('uicr', 0x1000)):
            data = bytes([0x5a]) * size
            for suffix in ('before', 'check'):
                name = f'{kind}-{suffix}.bin'
                (directory / name).write_bytes(data)
                sums.append(f'{digest(data)}  {name}')
        (directory / 'SHA256SUMS.txt').write_text('\n'.join(sums) + '\n')
        return directory

    def test_valid_local_preflight_is_read_only(self):
        backup = self.backup()
        before = {p.name: p.read_bytes() for p in backup.iterdir()}
        result = guard.preflight(self.image, self.sha.upper(), self.probe,
                                 flash=True, backup=backup)
        self.assertEqual(result['image_sha256'], self.sha)
        self.assertEqual(len(result['backup_sha256']), 4)
        self.assertEqual(before, {p.name: p.read_bytes() for p in backup.iterdir()})

    def test_missing_or_malformed_expected_hash(self):
        for sha in (None, '', '0' * 63, 'g' * 64, self.sha + '\n'):
            with self.subTest(sha=sha), self.assertRaises(ValueError):
                guard.preflight(self.image, sha, self.probe)

    def test_wrong_hash(self):
        with self.assertRaisesRegex(ValueError, 'differs'):
            guard.preflight(self.image, '0' * 64, self.probe)

    def test_probe_id_required(self):
        for probe in (None, '', ' ', ' probe '):
            with self.subTest(probe=probe), self.assertRaises(ValueError):
                guard.preflight(self.image, self.sha, probe)

    def test_reset_does_not_claim_backup_verification(self):
        result = guard.preflight(self.image, self.sha, self.probe)
        self.assertNotIn('backup_sha256', result)

    def test_flash_without_backup_refused(self):
        with self.assertRaisesRegex(ValueError, 'requires --backup'):
            guard.preflight(self.image, self.sha, self.probe, flash=True)

    def test_incomplete_backup_refused(self):
        backup = self.backup()
        (backup / 'uicr-check.bin').unlink()
        with self.assertRaises(OSError):
            guard.verify_backup(backup, self.probe)

    def test_backup_for_different_probe_refused(self):
        with self.assertRaisesRegex(ValueError, 'probe ID differs'):
            guard.verify_backup(self.backup(), 'OTHER')

    def test_changed_backup_bytes_refused(self):
        backup = self.backup()
        (backup / 'flash-before.bin').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'size or SHA-256'):
            guard.verify_backup(backup, self.probe)

    def test_checksum_alone_does_not_replace_independent_readback(self):
        backup = self.backup()
        data = bytes([0x33]) * 0x1000
        path = backup / 'uicr-check.bin'
        old = digest(path.read_bytes())
        path.write_bytes(data)
        sums = backup / 'SHA256SUMS.txt'
        sums.write_text(sums.read_text().replace(f'{old}  uicr-check.bin',
                                                 f'{digest(data)}  uicr-check.bin'))
        with self.assertRaisesRegex(ValueError, 'reads disagree'):
            guard.verify_backup(backup, self.probe)

    def test_duplicate_checksum_refused(self):
        backup = self.backup()
        sums = backup / 'SHA256SUMS.txt'
        sums.write_text(sums.read_text() * 2)
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            guard.verify_backup(backup, self.probe)

    def test_wrong_selected_probe_refused_before_open(self):
        session = MagicMock(probe=SimpleNamespace(unique_id='OTHER'))
        with self.assertRaises(ValueError):
            guard.verify_probe(session, self.probe)
        session.__enter__.assert_not_called()
        with self.assertRaises(ValueError):
            guard.verify_probe(None, self.probe)

    def arguments(self, tool, output, *extra):
        result = ['--motor-power-disconnected', '--probe-id', self.probe,
                  '--image-sha256', self.sha, '--port', 'FAKE-PORT',
                  '--output', str(output)]
        if tool is sensor:
            result.extend(['--context', 'Synthetic fixture; no device', '--reset'])
        return result + list(extra)

    def test_both_tools_refuse_hash_before_backend(self):
        for index, tool in enumerate((lamp, sensor)):
            with self.subTest(tool=tool.__name__), patch.object(tool, 'IMAGE', self.image):
                serial, session, programmer = Mock(), Mock(), Mock()
                output = self.root / f'capture-{index}'
                argv = self.arguments(tool, output)
                argv[argv.index(self.sha)] = '0' * 64
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    tool.main(argv, hardware=(serial, session, programmer))
                serial.assert_not_called(); session.assert_not_called(); programmer.assert_not_called()
                self.assertFalse(output.exists())

    def test_both_tools_refuse_flash_without_backup_before_backend(self):
        for index, tool in enumerate((lamp, sensor)):
            with self.subTest(tool=tool.__name__), patch.object(tool, 'IMAGE', self.image):
                hardware = tuple(Mock() for _ in range(3))
                output = self.root / f'flash-{index}'
                argv = [arg for arg in self.arguments(tool, output) if arg != '--reset'] + ['--flash']
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    tool.main(argv, hardware=hardware)
                for backend in hardware: backend.assert_not_called()

    def test_both_tools_refuse_wrong_probe_before_serial_or_session_open(self):
        for index, tool in enumerate((lamp, sensor)):
            with self.subTest(tool=tool.__name__), patch.object(tool, 'IMAGE', self.image):
                serial, programmer = Mock(), Mock()
                chosen = MagicMock(probe=SimpleNamespace(unique_id='OTHER'))
                session = Mock(return_value=chosen)
                output = self.root / f'probe-{index}'
                with contextlib.redirect_stdout(io.StringIO()):
                    rc = tool.main(self.arguments(tool, output), hardware=(serial, session, programmer))
                self.assertEqual(rc, 1)
                serial.assert_not_called(); programmer.assert_not_called()
                chosen.__enter__.assert_not_called()
                self.assertFalse(json.loads((output / 'capture.json').read_text())['completed'])

    def test_both_tools_never_reset_after_failed_readback(self):
        for index, tool in enumerate((lamp, sensor)):
            with self.subTest(tool=tool.__name__), patch.object(tool, 'IMAGE', self.image):
                link = MagicMock()
                link.__enter__.return_value = link
                serial = Mock(return_value=link)
                chosen = MagicMock(probe=SimpleNamespace(unique_id=self.probe))
                chosen.__enter__.return_value = chosen
                session = Mock(return_value=chosen)
                programmer = Mock()
                output = self.root / f'readback-{index}'
                with patch.object(tool, 'verify_image', side_effect=ValueError('synthetic readback mismatch')), \
                     contextlib.redirect_stdout(io.StringIO()):
                    rc = tool.main(self.arguments(tool, output), hardware=(serial, session, programmer))
                self.assertEqual(rc, 1)
                chosen.target.reset.assert_not_called()
                chosen.target.reset_and_halt.assert_not_called()
                programmer.assert_not_called()
                meta = json.loads((output / 'capture.json').read_text())
                self.assertFalse(meta['firmware_verified'])
                self.assertFalse(meta['completed'])
                self.assertFalse(link.dtr); self.assertFalse(link.rts)

    def test_flash_readback_failure_never_resets_or_claims_verified(self):
        backup = self.backup()
        for index, tool in enumerate((lamp, sensor)):
            with self.subTest(tool=tool.__name__), patch.object(tool, 'IMAGE', self.image):
                link = MagicMock(); link.__enter__.return_value = link
                chosen = MagicMock(probe=SimpleNamespace(unique_id=self.probe))
                chosen.__enter__.return_value = chosen
                programmer = Mock()
                output = self.root / f'flash-readback-{index}'
                argv = [arg for arg in self.arguments(tool, output) if arg != '--reset']
                argv.extend(['--flash', '--backup', str(backup)])
                with patch.object(tool, 'verify_image', side_effect=ValueError('synthetic readback mismatch')), \
                     contextlib.redirect_stdout(io.StringIO()):
                    rc = tool.main(argv, hardware=(Mock(return_value=link), Mock(return_value=chosen), programmer))
                self.assertEqual(rc, 1)
                chosen.target.reset_and_halt.assert_called_once_with()
                programmer.return_value.program.assert_called_once_with(str(self.image), file_format='elf')
                chosen.target.reset.assert_not_called()
                meta = json.loads((output / 'capture.json').read_text())
                self.assertFalse(meta['firmware_verified']); self.assertFalse(meta['completed'])

    def test_image_changed_after_preflight_refused_before_programming(self):
        backup = self.backup()
        original = self.image.read_bytes()
        for index, tool in enumerate((lamp, sensor)):
            self.image.write_bytes(original)
            with self.subTest(tool=tool.__name__), patch.object(tool, 'IMAGE', self.image):
                link = MagicMock(); link.__enter__.return_value = link
                chosen = MagicMock(probe=SimpleNamespace(unique_id=self.probe))
                chosen.__enter__.return_value = chosen
                def select(**kwargs):
                    self.image.write_bytes(b'changed after local preflight')
                    return chosen
                programmer = Mock()
                output = self.root / f'changed-image-{index}'
                argv = [arg for arg in self.arguments(tool, output) if arg != '--reset']
                argv.extend(['--flash', '--backup', str(backup)])
                with contextlib.redirect_stdout(io.StringIO()):
                    rc = tool.main(argv, hardware=(Mock(return_value=link), select, programmer))
                self.assertEqual(rc, 1)
                chosen.target.reset_and_halt.assert_not_called()
                programmer.assert_not_called()
                chosen.target.reset.assert_not_called()

    def test_elf_readback_mismatch_is_rejected(self):
        class Segment(dict):
            def data(self): return b'expected bytes'
        segment = Segment(p_type='PT_LOAD', p_filesz=14, p_paddr=0)
        elf = SimpleNamespace(iter_segments=lambda: iter([segment]))
        target = Mock()
        target.read_memory_block8.return_value = b'incorrect data'
        with patch.dict(sys.modules, {'elftools.elf.elffile': SimpleNamespace(ELFFile=lambda _: elf)}):
            with self.assertRaisesRegex(ValueError, 'reset refused'):
                sensor.verify_image(target, self.image)
        target.reset.assert_not_called()

    def test_elf_overflow_rejected_before_read(self):
        class Segment(dict):
            def data(self): return b'ab'
        segment = Segment(p_type='PT_LOAD', p_filesz=2, p_paddr=0x7ffff)
        elf = SimpleNamespace(iter_segments=lambda: iter([segment]))
        target = Mock()
        with patch.dict(sys.modules, {'elftools.elf.elffile': SimpleNamespace(ELFFile=lambda _: elf)}):
            with self.assertRaisesRegex(ValueError, 'exceeds'):
                sensor.verify_image(target, self.image)
        target.read_memory_block8.assert_not_called()


if __name__ == '__main__':
    unittest.main()
