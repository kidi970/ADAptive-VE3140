"""Synthetic preparation tests; no hardware or capture subprocesses."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from replay_sensors import prepare, run_filter


def row(seq, value, status='VALID_ECHO', phase='ALL_65', sensor='F'):
    return dict(seq=seq, legacy_cm=value, status=status, phase=phase, sensor=sensor, t_us=seq*65000)


class ReplayTests(unittest.TestCase):
    def test_status_and_large_values_veto(self):
        triples, _ = prepare([row(1, 100), row(2, 100, 'NO_FALL'), row(3, 999)])
        self.assertEqual(triples[0]['values'], [100, 0, 0])
        self.assertEqual(triples[0]['valid_raw'], 2)

    def test_phase_sensor_boundaries_and_tail(self):
        rows = [row(1, 100), row(2, 101), row(3, 102), row(4, 103),
                row(5, 200, phase='LEFT_65', sensor='L')]
        triples, tails = prepare(rows)
        self.assertEqual(len(triples), 1)
        self.assertEqual(tails, {'ALL_65/F': 1, 'LEFT_65/L': 1})
        self.assertEqual(triples[0]['span_us'], 130000)

    def test_actual_ada_filter_not_python_replica(self):
        triples = [{'values': values} for values in
                   ([100, 101, 102], [100, 0, 102], [20, 150, 151], [20, 100, 180], [200, 200, 201])]
        self.assertEqual(run_filter(triples), [100, 0, 20, 0, 0])


if __name__ == '__main__':
    unittest.main()
