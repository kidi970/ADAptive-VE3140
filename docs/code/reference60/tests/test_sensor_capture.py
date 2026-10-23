"""Synthetic protocol regressions; these are not physical measurements."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from sensor_experiment import PROFILES, validate_capture


def fixture(profile='gpio-v3'):
    phases = [(p, s) for p in ('ALL_65', 'ALL_100') for _ in range(40) for s in 'FLR']
    phases += [(p, 'L') for p in ('LEFT_65', 'LEFT_100') for _ in range(40)]
    rows = [dict(seq=i+1, phase=p, sensor=s) for i, (p, s) in enumerate(phases)]
    raw = '\n'.join([PROFILES[profile][0], *['DATA,sample' for _ in rows], PROFILES[profile][1]]).encode()
    return raw, rows


class CaptureTests(unittest.TestCase):
    def test_both_profiles(self):
        for profile in PROFILES:
            self.assertTrue(validate_capture(*fixture(profile), profile))

    def test_truncated_capture(self):
        raw, rows = fixture()
        self.assertFalse(validate_capture(raw, rows[:-1], 'gpio-v3'))

    def test_done_marker_is_not_sufficient(self):
        self.assertFalse(validate_capture(PROFILES['gpio-v3'][1].encode(), [], 'gpio-v3'))

    def test_wrong_or_repeated_firmware(self):
        raw, rows = fixture()
        self.assertFalse(validate_capture(raw, rows, 'v2'))
        self.assertFalse(validate_capture(PROFILES['gpio-v3'][0].encode()+b'\n'+raw, rows, 'gpio-v3'))

    def test_extra_samples(self):
        raw, rows = fixture()
        self.assertFalse(validate_capture(raw+b'\nDATA,extra', rows, 'gpio-v3'))

    def test_phase_or_sensor_substitution(self):
        raw, rows = fixture()
        for field, value in [('phase', 'LEFT_65'), ('sensor', 'R')]:
            bad = [*rows]; bad[0] = {**bad[0], field: value}
            self.assertFalse(validate_capture(raw, bad, 'gpio-v3'))

    def test_duplicate_sequence(self):
        raw, rows = fixture()
        rows[1]['seq'] = 1
        self.assertFalse(validate_capture(raw, rows, 'gpio-v3'))

    def test_fault_veto(self):
        raw, rows = fixture()
        self.assertFalse(validate_capture(raw+b'\nDIAGNOSTIC FAULT PROGRAM_ERROR', rows, 'gpio-v3'))

    def test_markers_must_surround_data(self):
        raw, rows = fixture()
        lines = raw.splitlines()
        self.assertFalse(validate_capture(b'\n'.join([lines[-1], *lines[:-1]]), rows, 'gpio-v3'))

    def test_usb_nul_prefix(self):
        raw, rows = fixture()
        self.assertTrue(validate_capture(b'\x00'+raw, rows, 'gpio-v3'))


if __name__ == '__main__':
    unittest.main()
