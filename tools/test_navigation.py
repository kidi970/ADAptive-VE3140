#!/usr/bin/env python3
"""Run the actual pure Ada policy/FSM on the host, outside the firmware tree."""
from pathlib import Path
import os, shutil, subprocess, tempfile
repo = Path(__file__).resolve().parents[1]
compiler = shutil.which('gnatmake')
if not compiler:
    roots = Path.home() / 'AppData/Local/alire/cache/toolchains'
    compiler = next((str(p) for p in roots.glob('gnat_native_*/bin/gnatmake.exe')), None)
if not compiler:
    raise SystemExit('Native gnatmake required; ARM compilation is not a host test.')
env = os.environ.copy()
env['PATH'] = str(Path(compiler).parent) + os.pathsep + env.get('PATH', '')
with tempfile.TemporaryDirectory(prefix='adaptive-tests-') as scratch:
    for suite in ('policy_tests', 'range_tests'):
        subprocess.run([compiler, '-q', '-gnat2022', '-gnata', '-gnato', '-g',
                        '-I' + str(repo / 'Code/src'), str(repo / f'tests/{suite}.adb'),
                        '-o', str(Path(scratch) / suite)], cwd=scratch, env=env, check=True)
        binary = Path(scratch) / (suite + ('.exe' if os.name == 'nt' else ''))
        subprocess.run([str(binary)], env=env, check=True)
