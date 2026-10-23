#!/usr/bin/env python3
"""Capture the stationary diagnostic; never flashes the autonomous main image.

Disconnect motor power first. Sensor power and USB must remain connected.
The output directory must be new, so earlier experimental evidence is preserved.
"""
import argparse
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
IMAGE = REPO / 'build/sensor-diagnostic/Code/diagnostics/obj/sensor_diagnostic'
HEADER = 'seq,phase,sensor,t_us,interval_ms,trigger_gap_us,status,pulse_us,elapsed_us,distance_milli_cm,legacy_cm'


def main():
    import serial
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flash', action='store_true')
    parser.add_argument('--port', default='COM5')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--context', required=True, help='Actual physical setup, not assumed reference distances')
    args = parser.parse_args()
    if not IMAGE.is_file():
        parser.error('Build Code/diagnostics/sensor_diagnostic.gpr first')
    args.output.mkdir(parents=True, exist_ok=False)
    meta = {'image': str(IMAGE), 'sha256': hashlib.sha256(IMAGE.read_bytes()).hexdigest(),
            'port': args.port, 'context': args.context, 'flash_requested': args.flash,
            'started_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'completed': False}
    raw = bytearray()
    try:
        with serial.Serial(args.port, 115200, timeout=.1) as port:
            port.reset_input_buffer()
            if args.flash:
                command = [sys.executable, '-m', 'pyocd', 'load', '-W', '-t', 'nrf52833',
                           '--format', 'elf', str(IMAGE)]
                try:
                    result = subprocess.run(command, cwd=REPO, capture_output=True, timeout=45)
                except subprocess.TimeoutExpired as exc:
                    (args.output / 'flash.txt').write_bytes((exc.stdout or b'') + (exc.stderr or b''))
                    raise
                (args.output / 'flash.txt').write_bytes(result.stdout + result.stderr)
                meta['flash_exit_code'] = result.returncode
                result.check_returncode()
            start = time.monotonic()
            while time.monotonic() - start < 60:
                raw.extend(port.read(4096))
                if b'DONE,320,MOTION_DISABLED' in raw or b'DIAGNOSTIC FAULT' in raw:
                    break
            meta['capture_seconds'] = round(time.monotonic() - start, 3)
            meta['completed'] = b'DONE,320,MOTION_DISABLED' in raw
    except Exception as exc:
        meta['error'] = f'{type(exc).__name__}: {exc}'
    finally:
        (args.output / 'serial.txt').write_bytes(raw)
        lines = [line[5:].strip() for line in raw.decode(errors='replace').splitlines()
                 if line.startswith('DATA,')]
        (args.output / 'samples.csv').write_text(HEADER + '\n' + '\n'.join(lines) + '\n', encoding='utf-8')
        meta['data_rows'] = len(lines)
        (args.output / 'capture.json').write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding='utf-8')
        print(json.dumps(meta, indent=2, ensure_ascii=False))
    return 0 if meta['completed'] and meta['data_rows'] == 320 else 1


if __name__ == '__main__':
    raise SystemExit(main())
