#!/usr/bin/env python3
"""Reject offline model/logger defects in temporary native builds, never devices."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
CASES = (
    ('omit-kinetic-braking', 'adaptive_offline_model.adb', 'offline_model_tests',
     '+ P.Speed_M_Per_S ** 2 / (2.0 * P.Deceleration_M_Per_S2)', '+ 0.0'),
    ('accept-timeout-ray', 'adaptive_offline_model.adb', 'offline_model_tests',
     'if not Usable (Scan (I), Now_Ms, Max_Age_Ms) then return R; end if;',
     'if False then return R; end if;'),
    ('reuse-consumed-generation', 'adaptive_offline_model.adb', 'offline_model_tests',
     'and then D.Generation > State.Last_Generation', 'and then True'),
    ('new-id-with-old-observations', 'adaptive_offline_model.adb', 'offline_model_tests',
     'and then (not State.Has_Accepted\n'
     '          or else D.Oldest_Ms > State.Last_Accepted_Issued_Ms)', 'and then True'),
    ('floor-independent-center-check', 'adaptive_offline_model.adb', 'offline_model_tests',
     "abs (Scan ((Scan'Length + 1) / 2).Distance_M - Guard.Front.Distance_M) > 0.15",
     "abs (Integer (Values ((Scan'Length + 1) / 2)) - Integer (G.Front)) > 15"),
    ('floor-previous-center-check', 'adaptive_offline_model.adb', 'offline_model_tests',
     'abs (Previous_Center.Distance_M - Scan (4).Distance_M) > 0.15',
     'abs (Integer (CM (Previous_Center)) - Integer (Values (4))) > 15'),
    ('logger-capacity-overrun', 'adaptive_log_core.ads', 'logger_tests',
     'Max_Line_Length : constant := 160;', 'Max_Line_Length : constant := 161;'),
    ('usb-led-writes-button-pin', 'adaptive_usb_io_core.adb', 'usb_io_tests',
     'Write_Level (15, True);', 'Write_Level (14, True);'),
)
UNITS = ('adaptive_policy.ads', 'adaptive_policy.adb',
         'adaptive_offline_model.ads', 'adaptive_offline_model.adb',
         'adaptive_log_core.ads', 'adaptive_log_core.adb',
         'adaptive_usb_io_core.ads', 'adaptive_usb_io_core.adb')


def run_case(compiler, suite, mutation=None):
    with tempfile.TemporaryDirectory(prefix='adaptive-offline-mutation-') as temporary:
        work = Path(temporary)
        for unit in UNITS:
            shutil.copyfile(REPO / 'Code/src' / unit, work / unit)
        shutil.copyfile(REPO / 'tests' / (suite + '.adb'), work / (suite + '.adb'))
        if mutation:
            name, unit, _, old, new = mutation
            source = work / unit
            text = source.read_text()
            if text.count(old) != 1:
                raise RuntimeError(f'mutation target drifted: {name}')
            source.write_text(text.replace(old, new))
        executable = work / (suite + ('.exe' if os.name == 'nt' else ''))
        built = subprocess.run([compiler, '-q', '-gnat2022', '-gnata', '-gnato', '-g',
                                suite + '.adb', '-o', str(executable)],
                               cwd=work, capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError('mutation must compile before it counts: ' + built.stderr)
        tested = subprocess.run([str(executable)], cwd=work, capture_output=True,
                                text=True, timeout=30)
        detail = (tested.stdout + tested.stderr).strip()
        if mutation:
            if tested.returncode == 0 or 'PROGRAM_ERROR' not in detail:
                raise RuntimeError(f'mutation escaped or failed unexpectedly: {mutation[0]}: {detail}')
        elif tested.returncode:
            raise RuntimeError(f'unmodified baseline failed: {suite}: {detail}')
        return {'suite': suite, 'compiled': True, 'exit_code': tested.returncode,
                'detail': detail}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    compiler = shutil.which('gnatmake')
    if not compiler:
        raise SystemExit('Native gnatmake required; ARM firmware is never executed.')
    paths = [REPO / 'Code/src' / name for name in UNITS]
    suites = sorted({case[2] for case in CASES})
    paths.extend(REPO / 'tests' / (name + '.adb') for name in suites)
    before = {str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in paths}
    report = {'hardware_access': False, 'source_sha256': before,
              'baselines': {}, 'mutations': []}
    for suite in suites:
        report['baselines'][suite] = run_case(compiler, suite)
    for mutation in CASES:
        result = run_case(compiler, mutation[2], mutation)
        result.update(name=mutation[0], rejected=True)
        report['mutations'].append(result)
        print(f'PASS mutation rejected: {mutation[0]}: {result["detail"].splitlines()[-1]}', flush=True)
    after = {str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
             for path in paths}
    if before != after:
        raise SystemExit('Source files changed during mutation checks; rerun on stable sources.')
    report['original_sources_unchanged'] = True
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
