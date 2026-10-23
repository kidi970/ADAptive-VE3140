#!/usr/bin/env python3
"""Descriptive HC-SR04 statistics. Error metrics require an explicit reference.

Reference JSON maps phase/sensor to measured cm, e.g. {"ALL_65/L": 60.0}.
No reference means error, MAE and RMSE are null, never errors against the mean.
"""
import argparse
import csv
import json
import math
import statistics
from collections import Counter, defaultdict
from pathlib import Path

STATUSES = {'VALID_ECHO', 'NO_RISE', 'NO_FALL', 'ECHO_ALREADY_HIGH', 'OUTSIDE_WORKING_RANGE'}
PHASES = {'ALL_65', 'ALL_100', 'LEFT_65', 'LEFT_100'}
NUMERIC = ('seq', 't_us', 'interval_ms', 'trigger_gap_us', 'pulse_us', 'elapsed_us', 'distance_milli_cm', 'legacy_cm')


def read_samples(path):
    rows = []
    with Path(path).open(encoding='utf-8-sig', newline='') as file:
        for line, item in enumerate(csv.DictReader(file), 2):
            try:
                item = {key.strip(): value.strip() for key, value in item.items()}
                for key in NUMERIC:
                    item[key] = int(item[key])
                    if item[key] < 0:
                        raise ValueError('negative value')
                if item['seq'] != len(rows) + 1:
                    raise ValueError('missing, repeated or reordered sequence')
                if item['status'] not in STATUSES or item['phase'] not in PHASES or item['sensor'] not in 'FLR' or len(item['sensor']) != 1:
                    raise ValueError('unknown category')
                if rows and item['t_us'] < rows[-1]['t_us']:
                    raise ValueError('nonmonotonic time')
                if item['pulse_us'] > item['elapsed_us']:
                    raise ValueError('pulse exceeds total read duration')
                if item['status'] == 'VALID_ECHO' and not 2000 <= item['distance_milli_cm'] <= 200000:
                    raise ValueError('valid distance outside working range')
                rows.append(item)
            except (ValueError, KeyError, AttributeError, TypeError) as exc:
                raise ValueError(f'Invalid CSV at line {line}: {exc}') from exc
    return rows


def errors(values, reference):
    if reference is None or not values:
        return {'bias_cm': None, 'mae_cm': None, 'rmse_cm': None}
    residuals = [value - reference for value in values]
    return {'bias_cm': statistics.mean(residuals),
            'mae_cm': statistics.mean(abs(value) for value in residuals),
            'rmse_cm': math.sqrt(statistics.mean(value * value for value in residuals))}


def filtered(triple, mode):
    # Every invalid sample vetoes both candidates. Neither fills unknown space.
    if any(item['status'] != 'VALID_ECHO' for item in triple):
        return None
    values = sorted(item['distance_milli_cm'] / 1000 for item in triple)
    if mode == 'median':
        return values[1]
    # Retain near obstacles; reject inconsistent triples. Evaluation only.
    return values[0] if values[2] - values[0] <= 15 else None


def summarize(rows, references=None):
    if references is None:
        references = {}
    if not isinstance(references, dict):
        raise ValueError('References must be a JSON object mapping phase/sensor to cm')
    for reference in references.values():
        if isinstance(reference, bool) or not isinstance(reference, (int, float)) or not math.isfinite(reference) or reference <= 0:
            raise ValueError('Reference distances must be positive finite cm')
    groups = defaultdict(list)
    phase_by_sequence = {row['seq']: row['phase'] for row in rows}
    for row in rows:
        groups[row['phase'] + '/' + row['sensor']].append(row)
    unknown = set(references) - set(groups)
    if unknown:
        raise ValueError('References for absent groups: ' + ', '.join(sorted(unknown)))
    result = {'samples': len(rows), 'groups': {}, 'per_sensor': {},
              'distance_metrics_exclude_invalid': True,
              'limitations': ['Fixed phase order; interval and isolation effects are confounded with time.',
                              'RTC timestamps and polling quantize pulse duration; distances are uncalibrated.',
                              'Observed maximum elapsed time is not a proven WCET.',
                              'Filtering statistics use nonoverlapping triples within each phase/sensor.']}
    for key, items in sorted(groups.items()):
        valid = [item for item in items if item['status'] == 'VALID_ECHO']
        values = [item['distance_milli_cm'] / 1000 for item in valid]
        rise_delays = [item['elapsed_us']-item['pulse_us'] for item in valid]
        reference = references.get(key)
        candidates = {}
        for mode in ('median', 'consistent_minimum'):
            triples = [items[i:i+3] for i in range(0, len(items)-2, 3)]
            accepted = [value for triple in triples if (value := filtered(triple, mode)) is not None]
            candidates[mode] = {'triples': len(triples), 'accepted': len(accepted),
                                'discarded_tail': len(items) % 3, **errors(accepted, reference)}
        result['groups'][key] = {
            'total': len(items), 'valid': len(valid), 'invalid_fraction': 1-len(valid)/len(items),
            'status_counts': dict(Counter(item['status'] for item in items)),
            'mean_cm': statistics.mean(values) if values else None,
            'median_cm': statistics.median(values) if values else None,
            'sample_stddev_cm': statistics.stdev(values) if len(values) >= 2 else None,
            'reference_cm': reference, **errors(values, reference),
            'max_read_elapsed_us': max(item['elapsed_us'] for item in items),
            'approx_rise_delay_median_us': statistics.median(rise_delays) if rise_delays else None,
            'approx_rise_delay_max_us': max(rise_delays) if rise_delays else None,
            'min_trigger_gap_us': min((item['trigger_gap_us'] for item in items
                                       if phase_by_sequence.get(item['seq']-1) == item['phase']), default=None),
            'mean_clock_minus_legacy_cm': statistics.mean(value-item['legacy_cm'] for value, item in zip(values, valid)) if values else None,
            'candidates': candidates}
    for sensor in sorted({row['sensor'] for row in rows}):
        items = [row for row in rows if row['sensor'] == sensor]
        values = [row['distance_milli_cm']/1000 for row in items if row['status'] == 'VALID_ECHO']
        keys = {row['phase'] + '/' + sensor for row in items}
        refs = [references.get(key) for key in keys]
        # Pool errors only when every included phase has the same reference.
        # Missing or different references must not silently become a common truth.
        reference = refs[0] if refs and None not in refs and len(set(refs)) == 1 else None
        result['per_sensor'][sensor] = {
            'total': len(items), 'valid': len(values), 'invalid': len(items)-len(values),
            'invalid_fraction': (len(items)-len(values))/len(items),
            'distance_metric_n': len(values), 'invalid_excluded_from_distance_metrics': True,
            'status_counts': dict(Counter(row['status'] for row in items)),
            'mean_cm': statistics.mean(values) if values else None,
            'median_cm': statistics.median(values) if values else None,
            'sample_stddev_cm': statistics.stdev(values) if len(values) >= 2 else None,
            'min_cm': min(values) if values else None, 'max_cm': max(values) if values else None,
            'reference_cm': reference, **errors(values, reference),
            'max_read_elapsed_us': max(row['elapsed_us'] for row in items)}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv', type=Path)
    parser.add_argument('--references', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    refs = json.loads(args.references.read_text(encoding='utf-8')) if args.references else None
    result = summarize(read_samples(args.csv), refs)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False), encoding='utf-8')
    print(json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False))


if __name__ == '__main__':
    main()
