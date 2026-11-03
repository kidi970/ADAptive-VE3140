#!/usr/bin/env python3
"""Demonstrate regression gates reject real defects, only in temporary copies."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import mb

REPO = Path(__file__).resolve().parents[1]
CASES = (
    ('latch failure suppresses motor stop', 'adaptive_fault_handler.adb', 'fault_tests',
     "      begin\n         Latch_Stop;\n      exception\n         when Latch_Error : others =>\n            Saved.Latch_Fault :=\n              Adaptive_Errors.Classify (Exception_Identity (Latch_Error));\n      end;",
     '      Latch_Stop;'),
    ('unarmed controller', 'adaptive_controller.adb', 'controller_tests',
     'if not Start_Requested then Pause (20); return; end if;', 'null;'),
    ('expired turn evidence', 'adaptive_controller.adb', 'controller_tests',
     'if Monitor_Motion (Turning => True) and then Turn_Evidence_Fresh then',
     'if Monitor_Motion (Turning => True) then'),
    ('OLED retry storm', 'adaptive_display.adb', 'display_tests',
     'Panel := Disabled;', 'Panel := Ready;'),
    ('missing motor FULL_OFF', 'adaptive_motion.adb', 'motion_tests',
     'Buffer (4 + 4 * Channel) := 16#10#;', 'Buffer (4 + 4 * Channel) := 0;'),
    ('front sampled before servo settles', 'adaptive_navigation.adb', 'navigation_tests',
     'delay until Center_Ready_At;', 'null;'),
)


def replace_once(path, old, new):
    content = path.read_text()
    if content.count(old) != 1:
        raise SystemExit(f'Mutation target drifted: {path.name}')
    path.write_text(content.replace(old, new))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--proof', action='store_true')
    args = parser.parse_args()
    compiler = shutil.which('gnatmake')
    if not compiler:
        raise SystemExit('Native gnatmake required')
    for name, unit, suite, old, new in CASES:
        with tempfile.TemporaryDirectory(prefix='adaptive-mutation-') as scratch:
            work = Path(scratch)
            shutil.copytree(REPO / 'Code/src', work / 'src')
            replace_once(work / 'src' / unit, old, new)
            adl = REPO / 'Code/libs/Ada_Drivers_Library'
            command = [compiler, '-q', '-gnat2022', '-gnata', '-gnato',
                       '-I' + str(REPO / 'tests/stubs'), '-I' + str(work / 'src'),
                       '-I' + str(adl / 'hal/src'),
                       '-I' + str(adl / 'components/src/dfrobot/dfr0548'),
                       str(REPO / f'tests/{suite}.adb'), '-o', str(work / suite)]
            built = subprocess.run(command, cwd=work, capture_output=True, text=True)
            if built.returncode:
                raise SystemExit('Mutation must compile before it can count: ' + built.stderr)
            tested = subprocess.run([str(work / suite)], cwd=work, capture_output=True, text=True)
            detail = (tested.stdout + tested.stderr).strip()
            if tested.returncode == 0 or 'PROGRAM_ERROR' not in detail:
                raise SystemExit(f'Mutation escaped or failed unexpectedly: {name}: {detail}')
            print(f'PASS mutation rejected: {name}: {detail.splitlines()[-1]}', flush=True)
    if args.proof:
        with tempfile.TemporaryDirectory(prefix='adaptive-proof-mutation-') as scratch:
            work = Path(scratch)
            for suffix in ('ads', 'adb'):
                shutil.copyfile(REPO / f'Code/src/adaptive_lamp_policy.{suffix}',
                                work / f'adaptive_lamp_policy.{suffix}')
            replace_once(work / 'adaptive_lamp_policy.adb',
                         'when Moving => return (False, False, False);',
                         'when Moving => return (True, False, False);')
            project = work / 'mutation.gpr'
            project.write_text('project Mutation is\n'
                               f' for Source_Dirs use ("{work.as_posix()}");\n'
                               f' for Object_Dir use "{(work / "obj").as_posix()}";\n'
                               ' for Target use "arm-eabi";\n'
                               ' for Runtime ("Ada") use "embedded-nrf52833";\n'
                               'end Mutation;\n')
            status, output = mb.capture(['alr', 'exec', '--', 'gnatprove', '-P', str(project),
                                        '-u', 'adaptive_lamp_policy.adb', '--mode=all',
                                        '--level=1', '--checks-as-errors=on', '--timeout=10', '-j1'])
            if status == 0 or 'postcondition might fail' not in output.lower():
                raise SystemExit('Expected a rejected SPARK postcondition: ' + output)
            print('PASS mutation rejected: SPARK moving brake violates postcondition')


if __name__ == '__main__':
    main()
