#!/usr/bin/env python3
"""Replay historical CSV triples through the real Ada filter on the host.

This is offline data analysis, not a new sensor trial or a route-clearance test.
No serial/USB/debug packages are imported. Only a native compiler and its
newly compiled host executable are started.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from analyze_sensors import read_samples

REPO = Path(__file__).resolve().parents[1]


def prepare(rows):
    groups = defaultdict(list)
    for row in rows:
        groups[row['phase'] + '/' + row['sensor']].append(row)
    triples = []
    tails = {}
    for key, items in sorted(groups.items()):
        tails[key] = len(items) % 3
        for index in range(0, len(items) - 2, 3):
            batch = items[index:index + 3]
            # The current production driver uses 58-us legacy counts. Keep
            # this explicit; clock-derived cm is a different diagnostic series.
            values = [r['legacy_cm'] if r['status'] == 'VALID_ECHO'
                      and 0 <= r['legacy_cm'] <= 400 else 0 for r in batch]
            triples.append({'group': key, 'sequence': [r['seq'] for r in batch],
                            'span_us': batch[-1]['t_us'] - batch[0]['t_us'],
                            'valid_raw': sum(r['status'] == 'VALID_ECHO' for r in batch),
                            'values': values})
    return triples, tails


def run_filter(triples):
    compiler = shutil.which('gnatmake')
    if not compiler:
        raise RuntimeError('Native gnatmake required; ARM firmware cannot run as a Linux host program')
    with tempfile.TemporaryDirectory(prefix='adaptive-replay-') as directory:
        exe = Path(directory) / 'replay_policy'
        subprocess.run([compiler, '-q', '-gnat2022', '-gnata', '-gnato',
                        '-I' + str(REPO / 'Code/src'),
                        str(REPO / 'tests/replay_policy.adb'), '-o', str(exe)],
                       cwd=directory, check=True, capture_output=True, text=True)
        payload = ''.join(' '.join(map(str, t['values'])) + '\n' for t in triples)
        result = subprocess.run([str(exe)], input=payload, text=True,
                                capture_output=True, check=True, timeout=30)
        values = [int(line) for line in result.stdout.splitlines()]
        if len(values) != len(triples):
            raise RuntimeError('Replay returned an incomplete filter trace')
        return values


def replay(paths, filter_runner=run_filter):
    reports = []
    for path in paths:
        path = Path(path)
        rows = read_samples(path)
        triples, tails = prepare(rows)
        filtered = filter_runner(triples)
        if len(filtered) != len(triples):
            raise ValueError('Incomplete filter results')
        for triple, value in zip(triples, filtered):
            triple['filtered_legacy_cm'] = value
        valid = sum(r['status'] == 'VALID_ECHO' for r in rows)
        reports.append({'source': str(path), 'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'samples': len(rows), 'valid_raw': valid,
                        'valid_fraction': valid / len(rows) if rows else None,
                        'triples': len(triples), 'accepted_triples': sum(v > 0 for v in filtered),
                        'discarded_tail_by_group': tails, 'trace': triples})
    return {'kind': 'offline replay of historical data', 'hardware_access': False,
            'distance_source': 'legacy_cm; invalid ECHO status maps to unknown (0)',
            'policy_sha256': hashlib.sha256((REPO / 'Code/src/adaptive_policy.adb').read_bytes()).hexdigest(),
            'limitations': ['Nonoverlapping triples within each phase/sensor; not a timed vehicle simulation.',
                            'No servo-angle or simultaneous clearance evidence; no turn permission is inferred.',
                            'The historical 60 cm reference is not applied as a calibration correction.',
                            'Accepted filter triples do not prove fresh evidence or a clear swept path.'],
            'files': reports}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csv', type=Path, action='append', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = replay(args.csv)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    for item in result['files']:
        print(f"REPLAY {item['source']}: {item['samples']} raw, {item['valid_raw']} valid, "
              f"{item['accepted_triples']}/{item['triples']} filter triples accepted")


if __name__ == '__main__':
    main()
