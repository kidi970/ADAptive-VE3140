import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / 'tools'))
from lamp_experiment import BANNER, MODES, validate


def fixture():
    patterns = {'PARKED': [(1, 0, 0)], 'BRAKING': [(1, 0, 0)],
                'MOVING': [(0, 0, 0)], 'TURNING_LEFT': [(0, 1, 0), (0, 0, 0)],
                'TURNING_RIGHT': [(0, 0, 1), (0, 0, 0)],
                'FAULTED': [(1, 1, 1), (1, 0, 0)]}
    rows = []
    for mode in MODES:
        for i in range(12):
            b, l, r = patterns[mode][i % len(patterns[mode])]
            rows.append({'mode': mode, 'mode_age_s': 0.2 + i / 10,
                         'brake': b, 'left': l, 'right': r})
    return (BANNER + '\n').encode(), rows


class LampCaptureTests(unittest.TestCase):
    def test_valid_register_trace(self):
        self.assertTrue(all(validate(*fixture()).values()))

    def test_wrong_or_repeated_firmware(self):
        raw, rows = fixture()
        self.assertFalse(all(validate(raw + raw, rows).values()))
        self.assertFalse(all(validate(b'other firmware\n', rows).values()))

    def test_missing_mode_or_missing_samples(self):
        raw, rows = fixture()
        self.assertFalse(all(validate(raw, [r for r in rows if r['mode'] != 'MOVING']).values()))
        self.assertFalse(all(validate(raw, []).values()))

    def test_wrong_pin_or_no_blink(self):
        raw, rows = fixture()
        for row in rows:
            if row['mode'] == 'TURNING_LEFT':
                row['left'], row['right'] = row['right'], row['left']
        self.assertFalse(all(validate(raw, rows).values()))
        raw, rows = fixture()
        for row in rows:
            if row['mode'] == 'FAULTED': row['left'] = row['right'] = 1
        self.assertFalse(all(validate(raw, rows).values()))

    def test_runtime_fault_veto(self):
        raw, rows = fixture()
        self.assertFalse(all(validate(raw + b'LAMP DIAGNOSTIC FAULT\n', rows).values()))


if __name__ == '__main__':
    unittest.main()
