#!/usr/bin/env python3
"""Prove guard tests reject bypasses, with in-memory patches and fake devices.

No source file is modified and no hardware package is imported. Each selected
test first passes unchanged, then must produce an assertion failure when its
guard is bypassed. The tests themselves prohibit subprocess creation.
"""
import contextlib
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tests'))
import test_diagnostic_guard as tests
import test_standalone_bench as standalone_tests


CASES = (
    ('wrong-probe guard', tests.DiagnosticGuardTests, tests.lamp, 'verify_probe', lambda *args: None,
     'test_both_tools_refuse_wrong_probe_before_serial_or_session_open'),
    ('image-hash guard', tests.DiagnosticGuardTests, tests.guard, 'image_hash', lambda *args: '0' * 64,
     'test_both_tools_refuse_hash_before_backend'),
    ('backup guard', tests.DiagnosticGuardTests, tests.guard, 'verify_backup', lambda *args: {},
     'test_both_tools_refuse_flash_without_backup_before_backend'),
    ('standalone wrong-probe guard', standalone_tests.StandaloneCaptureGuardTests,
     standalone_tests.bench, 'verify_probe', lambda *args: None,
     'test_wrong_returned_probe_refused_before_serial_or_debug_open'),
    ('standalone trigger spacing', standalone_tests.StandaloneTests,
     standalone_tests.bench, 'trigger_times_valid', lambda *args: True,
     'test_raw_trigger_times_must_advance_at_sensor_interval'),
    ('standalone RAW/frame consistency', standalone_tests.StandaloneTests,
     standalone_tests.bench, 'component_summary', lambda *args: ('CLEAR', ['100 CM'] * 3),
     'test_valid_raw_must_agree_with_frame_assessment_and_minimum'),
)


def run_one(test_class, name):
    log = io.StringIO()
    with contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
        result = unittest.TextTestRunner(stream=log).run(
            unittest.TestSuite([test_class(name)]))
    return result, log.getvalue()


def main():
    for name, test_class, module, function, replacement, test in CASES:
        baseline, log = run_one(test_class, test)
        if not baseline.wasSuccessful():
            raise SystemExit(f'Unchanged guard test failed: {name}\n{log}')
        with patch.object(module, function, replacement):
            result, log = run_one(test_class, test)
        if not result.failures or result.errors:
            raise SystemExit(f'Expected assertion rejection of {name}; mutation escaped or errored\n{log}')
        print(f'PASS mock-only mutation rejected: {name} ({len(result.failures)} assertion failures)')


if __name__ == '__main__':
    main()
