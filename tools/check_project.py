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
             and (p.suffix in ('.tex', '.bib') or 'figures' in p.parts
                  or 'current' in p.relative_to(REPO / 'docs').parts)]
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
            ('ada-tests', [py, 'tools/test_navigation.py']),
            ('python-tests', [py, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py']),
            ('mutations', [py, 'tools/test_mutations.py'] + (['--proof'] if args.full else []))]
    if args.full:
        jobs.extend([
            ('proof', [py, 'tools/prove_lamps.py']),
            ('main-build', [py, 'tools/mb.py', 'build', '--use', 'template']),
            ('sensor-v2-build', [py, 'tools/build_sensor_diagnostic.py']),
            ('gpio-v3-build', [py, 'tools/build_sensor_diagnostic.py', '--gpio-only']),
            ('lamp-build', [py, 'tools/build_lamp_diagnostic.py']),
            ('report-build', ['latexmk', '-cd', '-pdf', '-interaction=nonstopmode', '-halt-on-error',
                              '-outdir=' + str(REPO / 'build/report-ready'), 'docs/main.tex']),
            ('slides-build', ['latexmk', '-cd', '-pdf', '-interaction=nonstopmode', '-halt-on-error',
                              '-outdir=' + str(REPO / 'build/slides-ready'), 'docs/presentation.tex'])])
    report = {'timestamp_utc': datetime.now(timezone.utc).isoformat(), 'hardware_access': False,
              'scope': 'software checks; no physical timing or motion validation', 'checks': []}
    report['document_sha256'] = document_hashes()
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
    (out / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(1 if failed else 0)


if __name__ == '__main__':
    main()
