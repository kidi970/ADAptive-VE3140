#!/usr/bin/env python3
"""Run actual Ada policies, controller and application packages against fakes."""
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
    for suite in ('policy_tests', 'range_tests', 'fault_tests', 'lamp_tests', 'scan_tests',
                  'controller_tests', 'offline_model_tests', 'logger_tests', 'bench_tests',
                  'usb_io_tests'):
        subprocess.run([compiler, '-q', '-gnat2022', '-gnata', '-gnato', '-g',
                        '-I' + str(repo / 'Code/src'), str(repo / f'tests/{suite}.adb'),
                        '-o', str(Path(scratch) / suite)], cwd=scratch, env=env, check=True)
        binary = Path(scratch) / (suite + ('.exe' if os.name == 'nt' else ''))
        subprocess.run([str(binary)], env=env, check=True)
    # Hardware suites execute actual application packages against explicit
    # fakes. They never open USB/GPIO or reset/program the board.
    adl = repo / 'Code/libs/Ada_Drivers_Library'
    for suite in ('motion_tests', 'display_tests', 'safety_tests', 'navigation_tests'):
        subprocess.run([compiler, '-q', '-gnat2022', '-gnata', '-gnato', '-g',
                        '-I' + str(repo / 'tests/stubs'),
                        '-I' + str(repo / 'Code/src'),
                        '-I' + str(adl / 'hal/src'),
                        '-I' + str(adl / 'components/src/dfrobot/dfr0548'),
                        str(repo / f'tests/{suite}.adb'),
                        '-o', str(Path(scratch) / suite)],
                       cwd=scratch, env=env, check=True)
        binary = Path(scratch) / (suite + ('.exe' if os.name == 'nt' else ''))
        subprocess.run([str(binary)], env=env, check=True)
