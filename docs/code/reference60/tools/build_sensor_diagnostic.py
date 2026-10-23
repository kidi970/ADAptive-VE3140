#!/usr/bin/env python3
"""Build the stationary sensor image without replacing build/main.elf."""
import mb
import argparse

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gpio-only', action='store_true',
                        help='Build the sensor-only image; motor power must be disconnected')
    args = parser.parse_args()
    name = 'sensor_gpio_diagnostic' if args.gpio_only else 'sensor_diagnostic'
    raise SystemExit(mb.alr_exec([
        'gprbuild', '-p', '-P', f'Code/diagnostics/{name}.gpr',
        '--root-dir=.', '--relocate-build-tree=build/sensor-diagnostic']))
