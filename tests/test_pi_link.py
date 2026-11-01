import importlib.util
import json
import tempfile
import unittest
import contextlib
import io
from pathlib import Path
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location('pi_link', Path(__file__).parents[1] / 'tools/pi_link.py')
pi_link = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pi_link)


def port(name='/dev/ttyACM0', vid=0x0D28, pid=0x0204):
    return SimpleNamespace(device=name, vid=vid, pid=pid, serial_number='TEST')


class PassiveLinkTests(unittest.TestCase):
    def test_identify_only_microbit(self):
        microbit = port()
        self.assertEqual(pi_link.candidates([port(vid=None), port(pid=1), microbit]), [microbit])

    def test_absent_or_ambiguous(self):
        for ports in ([], [port(vid=1)], [port(), port('/dev/ttyACM1')]):
            with self.assertRaises(ValueError):
                pi_link.choose(ports)

    def test_explicit_port_must_match_usb_identity(self):
        self.assertEqual(pi_link.choose([port(), port('/dev/ttyACM1')], '/dev/ttyACM1').device,
                         '/dev/ttyACM1')
        with self.assertRaises(ValueError):
            pi_link.choose([port('/dev/ttyUSB0', vid=1)], '/dev/ttyUSB0')

    def test_capture_is_passive_and_preserves_bytes(self):
        class FakeSerial:
            def __init__(self, **kwargs):
                self.kwargs = kwargs

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def open(self):
                assert self.dtr is False and self.rts is False
                assert self.kwargs['port'] is None

            def read(self, size):
                return b'FAULT\xff\r\n'
            # No write/reset methods: a test fails if either is introduced.

        with tempfile.TemporaryDirectory() as scratch:
            out = Path(scratch) / 'capture'
            clock = iter([0.0, 0.1, 1.0, 1.1])
            meta = pi_link.listen(port(), out, 1, FakeSerial, lambda: next(clock))
            self.assertTrue(meta['capture_completed'])
            self.assertEqual(meta['writes_requested'], 0)
            self.assertFalse(meta['firmware_identity_verified'])
            self.assertEqual((out / 'serial.bin').read_bytes(), b'FAULT\xff\r\n')
            self.assertEqual(json.loads((out / 'capture.json').read_text()), meta)
            with self.assertRaises(FileExistsError):
                pi_link.listen(port(), out, 1, FakeSerial)

    def test_open_failure_keeps_evidence(self):
        def broken(**kwargs):
            raise OSError('injected disconnect')
        with tempfile.TemporaryDirectory() as scratch:
            out = Path(scratch) / 'capture'
            meta = pi_link.listen(port(), out, 1, broken)
            self.assertFalse(meta['capture_completed'])
            self.assertIn('injected disconnect', meta['error'])
            self.assertTrue((out / 'capture.json').is_file())

    def test_listen_requires_power_isolation_and_bounded_time(self):
        for argv in (['listen', '--output', 'unused'],
                     ['listen', '--output', 'unused', '--motor-power-disconnected', '--seconds', '0'],
                     ['listen', '--output', 'unused', '--motor-power-disconnected', '--seconds', '61']):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as result:
                pi_link.main(argv)
            self.assertEqual(result.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
