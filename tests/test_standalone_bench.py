"""Synthetic capture fault injection; never hardware measurements."""
import contextlib
import hashlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, Mock, patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from standalone_bench import validate, PROFILES, image_path
import standalone_bench as bench


def fixture(profile):
    lines = [PROFILES[profile][2]]
    if profile == 'usb':
        lines += ['MODEL,PASS,PULSE_US=3480,NOMINAL_CM=60; NOT_A_SENSOR_MEASUREMENT']
        lines += [f'TICK,{i},A=RELEASED,B=RELEASED' for i in range(1,13)]
    else:
        for frame in range(1,16):
            for sensor in 'FLR':
                for sample in range(3):
                    seq = (frame-1)*9 + 'FLR'.index(sensor)*3 + sample+1
                    lines += [f'RAW,{seq},{sensor},NO_RISE,0,10000,0,{seq*65000}']
            lines += [f'FRAME,{frame},UNKNOWN,OLED=FALSE,F=UNKNOWN,L=UNKNOWN,R=UNKNOWN']
    lines += [PROFILES[profile][3]]
    return '\n'.join(lines).encode()


class StandaloneTests(unittest.TestCase):
    def setUp(self):
        process = patch.object(subprocess,'Popen',side_effect=AssertionError('subprocess forbidden'))
        process.start(); self.addCleanup(process.stop)

    def test_profiles_accept_complete_logs(self):
        for profile in PROFILES:
            self.assertTrue(validate(fixture(profile),profile))

    def test_wrong_firmware(self):
        self.assertFalse(validate(fixture('usb'),'components'))

    def test_done_alone_and_truncation(self):
        for profile in PROFILES:
            self.assertFalse(validate(PROFILES[profile][3].encode(),profile))
            self.assertFalse(validate(fixture(profile).rsplit(b'\n',1)[0],profile))

    def test_fault_veto(self):
        for profile in PROFILES:
            self.assertFalse(validate(fixture(profile)+b'\nBENCH_FAULT,PROGRAM_ERROR',profile))

    def test_duplicate_banner(self):
        self.assertFalse(validate(PROFILES['usb'][2].encode()+b'\n'+fixture('usb'),'usb'))

    def test_sequence_sensor_and_frame_injection(self):
        raw=fixture('components')
        for changed in (raw.replace(b'RAW,1,F,',b'RAW,2,F,'),
                        raw.replace(b'RAW,1,F,',b'RAW,1,R,'),
                        raw.replace(b'FRAME,15,',b'FRAME,14,')):
            self.assertFalse(validate(changed,'components'))

    def test_done_must_follow_frames(self):
        lines=fixture('components').splitlines()
        self.assertFalse(validate(b'\n'.join([lines[0],lines[-1],*lines[1:-1]]),'components'))

    def test_frames_cannot_precede_own_readings(self):
        lines=fixture('components').splitlines()
        frame=lines.pop(10); lines.insert(1,frame)
        self.assertFalse(validate(b'\n'.join(lines),'components'))

    def test_usb_model_required(self):
        lines=[line for line in fixture('usb').splitlines() if not line.startswith(b'MODEL,')]
        self.assertFalse(validate(b'\n'.join(lines),'usb'))

    def test_images_do_not_replace_navigation(self):
        for profile in PROFILES:
            self.assertNotEqual(image_path(profile).name,'main.elf')
            self.assertIn('standalone',image_path(profile).parts)

    def test_malformed_sensor_payloads(self):
        raw=fixture('components')
        for replacement in (b'RAW,1,F',b'RAW,1,F,FREE,0,10000,0,65000',
                            b'RAW,1,F,NO_RISE,0,-1,0,65000',
                            b'RAW,1,F,VALID_ECHO,3480,4000,100000,65000'):
            self.assertFalse(validate(raw.replace(b'RAW,1,F,NO_RISE,0,10000,0,65000',replacement),'components'))

    def test_malformed_button_state(self):
        self.assertFalse(validate(fixture('usb').replace(b'A=RELEASED',b'A=UNKNOWN'),'usb'))

    def test_raw_trigger_times_must_advance_at_sensor_interval(self):
        raw = fixture('components')
        for replacement in (b'RAW,2,F,NO_RISE,0,10000,0,65000',
                            b'RAW,2,F,NO_RISE,0,10000,0,65001',
                            b'RAW,2,F,NO_RISE,0,10000,0,129998'):
            self.assertFalse(validate(raw.replace(b'RAW,2,F,NO_RISE,0,10000,0,130000',replacement),'components'))

    def test_unknown_raw_cannot_claim_clear_frame_or_numeric_distance(self):
        raw = fixture('components')
        for replacement in (b'FRAME,1,CLEAR,OLED=FALSE,F=UNKNOWN,L=UNKNOWN,R=UNKNOWN',
                            b'FRAME,1,UNKNOWN,OLED=FALSE,F=99 CM,L=UNKNOWN,R=UNKNOWN',
                            b'FRAME,1,UNKNOWN,OLED=FALSE,F=UNKNOWN,L=UNKNOWN,L=UNKNOWN'):
            self.assertFalse(validate(raw.replace(
                b'FRAME,1,UNKNOWN,OLED=FALSE,F=UNKNOWN,L=UNKNOWN,R=UNKNOWN', replacement),'components'))

    def test_valid_raw_must_agree_with_frame_assessment_and_minimum(self):
        raw = fixture('components')
        lines = raw.splitlines()
        for index, line in enumerate(lines):
            if line.startswith(b'RAW,'):
                fields = line.decode().split(',')
                fields[3:7] = ['VALID_ECHO', '5800', '6000', '100000']
                lines[index] = ','.join(fields).encode()
            elif line.startswith(b'FRAME,'):
                fields = line.decode().split(',')
                fields[2:] = ['CLEAR', 'OLED=FALSE', 'F= 100 CM', 'L= 100 CM', 'R= 100 CM']
                lines[index] = ','.join(fields).encode()
        valid = b'\n'.join(lines)
        self.assertTrue(validate(valid,'components'))
        self.assertFalse(validate(valid.replace(b'F= 100 CM', b'F= 101 CM'), 'components'))
        self.assertFalse(validate(valid.replace(b',CLEAR,', b',CAUTION,'), 'components'))
        # A single long reading among unstable samples cannot claim CLEAR.
        changed = valid.replace(b'RAW,1,F,VALID_ECHO,5800,6000,100000,65000',
                                b'RAW,1,F,VALID_ECHO,1160,1500,20000,65000')
        self.assertFalse(validate(changed, 'components'))

    def test_oled_cannot_recover_without_new_initialization(self):
        self.assertFalse(validate(fixture('components').replace(
            b'FRAME,2,UNKNOWN,OLED=FALSE', b'FRAME,2,UNKNOWN,OLED=TRUE'), 'components'))


class StandaloneCaptureGuardTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.image = self.root / 'standalone_usb'
        self.image.write_bytes(b'synthetic standalone image')
        self.sha = hashlib.sha256(self.image.read_bytes()).hexdigest()
        self.probe = 'SYNTHETIC-PROBE'
        self.args = SimpleNamespace(output=self.root/'capture', profile='usb',
            detached_from_car=True, flash=True, port='FAKE-PORT', probe_id=self.probe,
            image_sha256=self.sha, backup=None)
        self.serial = Mock()
        device = SimpleNamespace(device='FAKE-PORT',vid=0x0D28,pid=0x0204,serial_number=self.probe)
        self.ports = Mock(return_value=[device])
        self.chosen = MagicMock(probe=SimpleNamespace(unique_id=self.probe))
        self.chosen.__enter__.return_value = self.chosen
        self.sessions = Mock(return_value=self.chosen)
        self.programmer = Mock()
        self.hardware = (self.serial,self.ports,self.sessions,self.programmer)
        for p in (patch.object(bench,'image_path',return_value=self.image),
                  patch.object(bench,'link_check',return_value={'passed':True}),
                  patch.object(subprocess,'Popen',side_effect=AssertionError('subprocess forbidden'))):
            p.start(); self.addCleanup(p.stop)

    def capture(self):
        with contextlib.redirect_stdout(io.StringIO()):
            rc = bench.capture(self.args,hardware=self.hardware)
        return rc, json.loads((self.args.output/'capture.json').read_text())

    def assert_no_backend(self):
        for backend in self.hardware: backend.assert_not_called()

    def test_wrong_hash_refused_before_usb_inventory(self):
        self.args.image_sha256 = '0'*64
        rc, meta = self.capture()
        self.assertEqual(rc,1); self.assertFalse(meta['completed'])
        self.assert_no_backend()

    def test_flash_requires_backup_before_usb_inventory(self):
        rc, meta = self.capture()
        self.assertEqual(rc,1); self.assertIn('--backup',meta['error'])
        self.assert_no_backend()

    def test_capture_requires_specific_probe_and_port(self):
        self.args.flash = False; self.args.probe_id = None
        rc, meta = self.capture()
        self.assertEqual(rc,1); self.assertIn('--probe-id',meta['error'])
        self.assert_no_backend()

    def test_uart_probe_mismatch_refused_before_open(self):
        self.args.flash = False
        self.ports.return_value[0].serial_number = 'OTHER'
        rc, meta = self.capture()
        self.assertEqual(rc,1)
        self.serial.assert_not_called(); self.sessions.assert_not_called()

    def flash_prerequisites(self):
        # The shared backup checker has independent full-byte fixture tests;
        # these call-chain tests fake it to prohibit every external dependency.
        local = patch.object(bench,'preflight',return_value={'image_sha256':self.sha})
        local.start(); self.addCleanup(local.stop)

    def test_wrong_returned_probe_refused_before_serial_or_debug_open(self):
        self.flash_prerequisites(); self.chosen.probe.unique_id = 'OTHER'
        rc, meta = self.capture()
        self.assertEqual(rc,1)
        self.serial.assert_not_called(); self.programmer.assert_not_called()
        self.chosen.__enter__.assert_not_called()
        self.assertFalse(self.sessions.call_args.kwargs['options']['auto_unlock'])
        self.assertFalse(self.sessions.call_args.kwargs['return_first'])

    def test_readback_failure_never_resets_or_claims_verified(self):
        self.flash_prerequisites()
        link = MagicMock(); link.__enter__.return_value = link
        def check_control_lines():
            self.assertIs(link.dtr,False); self.assertIs(link.rts,False)
        link.open.side_effect = check_control_lines
        self.serial.return_value = link
        with patch.object(bench,'verify_image',side_effect=ValueError('synthetic mismatch')):
            rc, meta = self.capture()
        self.assertEqual(rc,1); self.assertFalse(meta['firmware_verified'])
        self.chosen.target.reset.assert_not_called()
        self.programmer.return_value.program.assert_called_once_with(str(self.image),file_format='elf')
        self.serial.assert_called_once_with(port=None,baudrate=115200,timeout=.1,
                                            xonxoff=False,rtscts=False,dsrdtr=False)
        self.assertFalse(link.dtr); self.assertFalse(link.rts)

    def test_serial_only_capture_never_claims_firmware_verified(self):
        self.args.flash = False
        link = MagicMock(); link.__enter__.return_value = link
        link.read.return_value = fixture('usb')
        self.serial.return_value = link
        with patch.object(bench.time,'monotonic',side_effect=[0,.01,.02]):
            rc, meta = self.capture()
        self.assertEqual(rc,0); self.assertTrue(meta['completed'])
        self.assertFalse(meta['firmware_verified'])
        self.sessions.assert_not_called(); self.programmer.assert_not_called()


class StandaloneBuildTests(unittest.TestCase):
    def setUp(self):
        process = patch.object(subprocess,'Popen',side_effect=AssertionError('subprocess forbidden'))
        process.start(); self.addCleanup(process.stop)

    def test_build_only_starts_compiler_and_objcopy(self):
        with patch.object(bench.mb,'alr_exec',return_value=0) as run, \
             patch.object(bench,'link_check',return_value={'passed':True}), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(bench.build('usb'),0)
        self.assertEqual([call.args[0][0] for call in run.call_args_list], ['gprbuild','arm-eabi-objcopy'])
        self.assertNotIn('flash',str(run.call_args_list))

    def test_build_flash_flag_rejected_before_build(self):
        with patch.object(bench,'build') as build, contextlib.redirect_stderr(io.StringIO()), \
             self.assertRaises(SystemExit):
            bench.main(['build','--profile','usb','--flash'])
        build.assert_not_called()

    def test_usb_link_dependency_allowlist_rejects_hardware_packages(self):
        # The stdlib ELF parser is separately tested with actual ELF structures.
        # Here its inventory is mocked so every forbidden dependency is exercised.
        with tempfile.TemporaryDirectory() as scratch:
            image = Path(scratch)/'fake.elf'; image.write_bytes(b'fake fixture')
            for symbol in ('adaptive_motion__drive', 'dfr0548__motor', 'microbit__servos__set',
                           'microbit__ultrasonic__read', 'adaptive_sensors__read',
                           'adaptive_bench_oled__initialize', 'adaptive_oled_codec__encode_line',
                           'microbit__i2c__initializeext','nrf__twi__master_transmit'):
                with self.subTest(symbol=symbol), patch('audit_firmware.inspect_elf',return_value={'symbols':{symbol:{}}}):
                    with self.assertRaises(ValueError): bench.link_check(image,'usb')
            with patch('audit_firmware.inspect_elf',return_value={'symbols':{'standalone_usb':{}}}):
                self.assertTrue(bench.link_check(image,'usb')['passed'])


if __name__=='__main__':
    unittest.main()
