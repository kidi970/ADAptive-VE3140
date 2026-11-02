#!/usr/bin/env python3
"""Build GPIO-only lamp diagnostics without staging/flashing autonomous firmware."""
import mb

if __name__ == '__main__':
    raise SystemExit(mb.alr_exec([
        'gprbuild', '-p', '-P', 'Code/diagnostics/lamp_diagnostic.gpr',
        '--root-dir=.', '--relocate-build-tree=build/lamp-diagnostic']))
