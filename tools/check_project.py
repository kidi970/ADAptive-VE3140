#!/usr/bin/env python3
"""Reproduce software checks without opening USB or programming a board."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime, timezone

REPO = Path(__file__).resolve().parents[1]


def document_hashes():
    paths = [p for p in (REPO / 'docs').rglob('*') if p.is_file()
             and (p.suffix in ('.tex', '.bib', '.md') or 'figures' in p.parts
                  or 'current' in p.relative_to(REPO / 'docs').parts)]
    return {p.relative_to(REPO).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


def verification_inputs():
    """Bind results to the tests and tools too, not just application sources."""
    paths = {REPO / 'alire.toml'}
    for directory in ('Code/src', 'Code/diagnostics', 'Code/bench', 'tests', 'tools', 'proof', 'patches'):
        paths.update(p for p in (REPO / directory).rglob('*') if p.is_file()
                     and p.suffix in ('.ads', '.adb', '.gpr', '.py', '.patch'))
    return {p.relative_to(REPO).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--full', action='store_true', help='Also prove, build four images and compile both PDFs')
    parser.add_argument('--out', type=Path, default=REPO / 'build/readiness-review')
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    py = sys.executable
    jobs = [('report-sources', [py, 'tools/sync_report_sources.py', '--check']),
            ('driver-patch', ['git', '-C', 'Code/libs/Ada_Drivers_Library', 'apply',
                              '--reverse', '--check', '../../../patches/ada-drivers-2026-10-23.patch']),
            ('ada-tests', [py, 'tools/test_navigation.py']),
            ('python-tests', [py, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py']),
            ('mutations', [py, 'tools/test_mutations.py'] + (['--proof'] if args.full else [])),
            ('guard-mutations', [py, 'tools/test_diagnostic_guard_mutations.py']),
            ('offline-mutations', [py, 'tools/test_offline_mutations.py']),
            ('historical-replay', [py, 'tools/replay_sensors.py',
                                  '--csv', 'docs/evidence/2026-10-23-reference60/run-02/samples.csv',
                                  '--csv', 'docs/evidence/2026-10-23-reference60/run-03/samples.csv',
                                  '--csv', 'docs/evidence/2026-10-23-reference60/run-04/samples.csv',
                                  '--csv', 'docs/evidence/2026-11-02-lights-scan/gpio-baseline/samples.csv',
                                  '--output', str(out / 'historical-replay.json')])]
    if args.full:
        jobs.extend([
            ('proof', [py, 'tools/prove_lamps.py']),
            ('main-build', [py, 'tools/mb.py', 'build', '--use', 'template']),
            ('sensor-v2-build', [py, 'tools/build_sensor_diagnostic.py']),
            ('gpio-v3-build', [py, 'tools/build_sensor_diagnostic.py', '--gpio-only']),
            ('lamp-build', [py, 'tools/build_lamp_diagnostic.py']),
            ('standalone-usb-build', [py, 'tools/standalone_bench.py', 'build', '--profile', 'usb']),
            ('standalone-components-build', [py, 'tools/standalone_bench.py', 'build', '--profile', 'components']),
            ('firmware-audit', [py, 'tools/audit_firmware.py', '--out', str(out / 'firmware-audit.json')]),
            ('usb-audit', [py, 'tools/audit_firmware.py',
                           '--elf', 'build/standalone/Code/bench/obj-usb/standalone_usb',
                           '--hex', 'build/standalone/usb.hex',
                           '--object-dir', 'build/standalone/Code/bench/obj-usb',
                           '--binder', 'build/standalone/Code/bench/obj-usb/b__standalone_usb.adb',
                           '--out', str(out / 'usb-audit.json')]),
            ('components-audit', [py, 'tools/audit_firmware.py',
                                  '--elf', 'build/standalone/Code/bench/obj-components/standalone_components',
                                  '--hex', 'build/standalone/components.hex',
                                  '--object-dir', 'build/standalone/Code/bench/obj-components',
                                  '--binder', 'build/standalone/Code/bench/obj-components/b__standalone_components.adb',
                                  '--out', str(out / 'components-audit.json')]),
            ('report-build', ['latexmk', '-cd', '-pdf', '-interaction=nonstopmode', '-halt-on-error',
                              '-outdir=' + str(REPO / 'build/report-ready'), 'docs/main.tex']),
            ('slides-build', ['latexmk', '-cd', '-pdf', '-interaction=nonstopmode', '-halt-on-error',
                              '-outdir=' + str(REPO / 'build/slides-ready'), 'docs/presentation.tex'])])
    report = {'timestamp_utc': datetime.now(timezone.utc).isoformat(), 'hardware_access': False,
              'scope': 'software checks; no physical timing or motion validation', 'checks': []}
    report['document_sha256'] = document_hashes()
    report['verification_inputs_sha256'] = verification_inputs()
    failed = False
    for name, command in jobs:
        print(f'Checking {name} ...', flush=True)
        with (out / f'{name}.log').open('w') as log:
            result = subprocess.run(command, cwd=REPO, stdout=log, stderr=subprocess.STDOUT)
        entry = {'name': name, 'command': command, 'exit_code': result.returncode}
        if name == 'ada-tests':
            entry['assertion_counts'] = [int(re.search(r'\d+', line).group())
                                         for line in (out / f'{name}.log').read_text().splitlines()
                                         if line.startswith('PASS')]
        report['checks'].append(entry)
        print(f'{"PASS" if result.returncode == 0 else "FAIL"} {name}', flush=True)
        if result.returncode:
            print((out / f'{name}.log').read_text()[-5000:])
            failed = True
    from sync_report_sources import sources
    report['source_sha256'] = {n: hashlib.sha256(d).hexdigest() for n, d in sources().items()}
    report['passed'] = not failed
    if report['document_sha256'] != document_hashes():
        report['passed'] = False
        failed = True
        print('FAIL document sources changed during verification; run again')
    if report['verification_inputs_sha256'] != verification_inputs():
        report['passed'] = False
        failed = True
        print('FAIL test or tool sources changed during verification; run again')
    (out / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(1 if failed else 0)


if __name__ == '__main__':
    main()
