#!/usr/bin/env python3
"""Prove the actual lamp output interlocks, not a copy or the whole vehicle."""
import mb

if __name__ == '__main__':
    raise SystemExit(mb.alr_exec([
        'gnatprove', '-P', 'proof/lamps.gpr', '-u', 'adaptive_lamp_policy.adb',
        '--mode=all', '--level=1', '--report=all', '--checks-as-errors=on',
        '--timeout=10', '-j1']))
