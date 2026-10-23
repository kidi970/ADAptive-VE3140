"""Synthetic checks of the analysis pipeline, not physical sensor results."""
import csv
import math
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import analyze_sensors as analysis
from sensor_experiment import HEADER


def row(seq=1, distance=100000, status='VALID_ECHO'):
    return dict(seq=seq, phase='ALL_65', sensor='L', t_us=seq*65000,
                interval_ms=65, trigger_gap_us=65000, status=status, pulse_us=5800,
                elapsed_us=6000, distance_milli_cm=distance, legacy_cm=95)


class AnalysisTests(unittest.TestCase):
    def summary(self, rows, refs=None):
        return analysis.summarize(rows, refs)['groups']['ALL_65/L']

    def test_known_reference(self):
        result = self.summary([row(i+1, d*1000) for i, d in enumerate((98,100,102))], {'ALL_65/L': 100})
        self.assertEqual((result['mean_cm'], result['median_cm'], result['sample_stddev_cm']), (100,100,2))
        self.assertEqual(result['bias_cm'], 0)
        self.assertAlmostEqual(result['mae_cm'], 4/3)
        self.assertAlmostEqual(result['rmse_cm'], math.sqrt(8/3))

    def test_reference_never_invented(self):
        result = self.summary([row()])
        for name in ('bias_cm','mae_cm','rmse_cm','reference_cm','sample_stddev_cm'):
            self.assertIsNone(result[name])

    def test_all_invalid(self):
        result = self.summary([row(status='NO_RISE', distance=0)])
        self.assertEqual(result['invalid_fraction'], 1)
        self.assertIsNone(result['mean_cm'])
        self.assertIsNone(result['rmse_cm'])

    def test_invalid_fraction(self):
        self.assertEqual(self.summary([row(),row(2,0,'NO_FALL')])['invalid_fraction'], .5)

    def test_invalid_vetoes_every_candidate(self):
        for status in analysis.STATUSES - {'VALID_ECHO'}:
            triple = [row(1),row(2,0,status),row(3)]
            for mode in ('median','consistent_minimum'):
                self.assertIsNone(analysis.filtered(triple,mode))

    def test_near_obstacle_preserved(self):
        triple = [row(i+1, d*1000) for i,d in enumerate((90,100,101))]
        self.assertEqual(analysis.filtered(triple,'consistent_minimum'),90)
        self.assertEqual(analysis.filtered(triple,'median'),100)

    def test_inconsistent_rejected(self):
        self.assertIsNone(analysis.filtered([row(1,20000),row(2),row(3)],'consistent_minimum'))

    def test_incomplete_triple_disclosed(self):
        result = self.summary([row(i+1) for i in range(4)])['candidates']['median']
        self.assertEqual((result['triples'],result['accepted'],result['discarded_tail']),(1,1,1))

    def test_bad_references(self):
        for refs in ([],[100],100):
            with self.assertRaises(ValueError): self.summary([row()],refs)
        for ref in (0,-1,float('nan'),float('inf'),True,'100'):
            with self.assertRaises(ValueError):
                self.summary([row()], {'ALL_65/L':ref})
        with self.assertRaises(ValueError):
            self.summary([row()], {'ALL_65/F':100})

    def parse(self, rows):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'samples.csv'
            with path.open('w', newline='') as file:
                writer = csv.DictWriter(file, fieldnames=HEADER.split(','))
                writer.writeheader()
                writer.writerows(rows)
            return analysis.read_samples(path)

    def test_csv_round_trip(self):
        self.assertEqual(self.parse([row()]), [row()])

    def test_missing_or_duplicate_sequence(self):
        for second in (row(1),row(3)):
            with self.assertRaises(ValueError): self.parse([row(),second])

    def test_bad_csv_values(self):
        for key,value in (('sensor','FL'),('sensor',''),('status','FREE'),('phase','BAD'),
                          ('pulse_us',-1),('pulse_us','nan'),('distance_milli_cm',200001),
                          ('distance_milli_cm',1999),('pulse_us',7000)):
            with self.subTest(key=key,value=value), self.assertRaises(ValueError):
                self.parse([{**row(),key:value}])

    def test_nonmonotonic_time(self):
        with self.assertRaises(ValueError): self.parse([row(),{**row(2),'t_us':0}])

    def test_empty_file(self):
        self.assertEqual(analysis.summarize(self.parse([]))['samples'],0)

    def test_phase_boundary_gap_excluded(self):
        rows = [row(),{**row(2),'phase':'ALL_100','trigger_gap_us':65000},
                {**row(3),'phase':'ALL_100','trigger_gap_us':100000}]
        result = analysis.summarize(rows)['groups']['ALL_100/L']
        self.assertEqual(result['min_trigger_gap_us'],100000)

    def test_rise_delay_uses_only_valid_echoes(self):
        result = self.summary([row(),row(2,0,'NO_RISE')])
        self.assertEqual(result['approx_rise_delay_median_us'],200)
        self.assertEqual(result['approx_rise_delay_max_us'],200)


if __name__ == '__main__':
    unittest.main()
