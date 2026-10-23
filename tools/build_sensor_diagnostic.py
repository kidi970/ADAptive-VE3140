#!/usr/bin/env python3
"""Build the stationary sensor image without replacing build/main.elf."""
import mb

if __name__ == '__main__':
    raise SystemExit(mb.alr_exec([
        'gprbuild', '-p', '-P', 'Code/diagnostics/sensor_diagnostic.gpr',
        '--root-dir=.', '--relocate-build-tree=build/sensor-diagnostic']))
