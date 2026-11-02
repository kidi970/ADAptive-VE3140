#!/usr/bin/env python3
"""Verify stationary lamp firmware via serial and GPIO output registers.

Motor power must be isolated. This diagnostic has no motor/servo I2C calls.
Register observations do not verify LED wiring, current or visible light.
"""
import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

from sensor_experiment import verify_image, utc_now

REPO = Path(__file__).resolve().parents[1]
IMAGE = REPO / 'build/lamp-diagnostic/Code/diagnostics/obj-lamps/lamp_diagnostic'
BANNER = 'ADAptive LAMP DIAGNOSTIC v1; NO_MOTOR_I2C; P0_BRAKE P12_LEFT P16_RIGHT'
MODES = ('PARKED', 'TURNING_LEFT', 'TURNING_RIGHT', 'MOVING', 'BRAKING', 'FAULTED')


def validate(raw, samples):
    text = raw.decode(errors='replace')
    checks = {'banner_once': text.count(BANNER) == 1,
              'no_diagnostic_fault': 'LAMP DIAGNOSTIC FAULT' not in text}
    for mode in MODES:
        rows = [r for r in samples if r['mode'] == mode and r['mode_age_s'] >= 0.15]
        values = {(r['brake'], r['left'], r['right']) for r in rows}
        expected = ({(1, 0, 0)} if mode in ('PARKED', 'BRAKING') else
                    {(0, 0, 0)} if mode == 'MOVING' else
                    {(0, 0, 0), (0, 1, 0)} if mode == 'TURNING_LEFT' else
                    {(0, 0, 0), (0, 0, 1)} if mode == 'TURNING_RIGHT' else
                    {(1, 0, 0), (1, 1, 1)})
        checks[mode] = len(rows) >= 10 and values == expected
    return checks


def main():
    import serial
    from pyocd.core.helpers import ConnectHelper
    from pyocd.flash.file_programmer import FileProgrammer
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flash', action='store_true')
    parser.add_argument('--motor-power-disconnected', action='store_true', required=True)
    parser.add_argument('--leds-mounted', action='store_true', help='Record actual wiring, not an assumption')
    parser.add_argument('--port', required=True)
    parser.add_argument('--probe-id', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not IMAGE.is_file(): parser.error('Build lamp_diagnostic first')
    args.output.mkdir(parents=True, exist_ok=False)
    meta = {'started_utc': utc_now(), 'image_sha256': hashlib.sha256(IMAGE.read_bytes()).hexdigest(),
            'motor_power_disconnected_reported': True, 'leds_mounted_reported': args.leds_mounted,
            'flash_requested': args.flash, 'completed': False, 'firmware_verified': False,
            'physical_light_or_voltage_verified': False, 'motor_commands_sent': 0}
    raw = bytearray(); samples = []
    try:
        options = {'connect_mode': 'attach', 'auto_unlock': False,
                   'resume_on_disconnect': False, 'cmsis_dap.prefer_v1': True,
                   'cmsis_dap.limit_packets': True, 'cmsis_dap.deferred_transfers': False}
        with serial.Serial(port=None, baudrate=115200, timeout=0.05) as link:
            link.dtr = False; link.rts = False; link.port = args.port; link.open()
            with ConnectHelper.session_with_chosen_probe(unique_id=args.probe_id,
                    target_override='nrf52833', options=options, blocking=False,
                    return_first=False) as session:
                target = session.target
                if args.flash:
                    # Attaching to a sleeping task can retain PSP/exception
                    # state that is unsuitable for executing a RAM flash algo.
                    target.reset_and_halt()
                    FileProgrammer(session).program(str(IMAGE), file_format='elf')
                meta['flash_segments'] = verify_image(target, IMAGE)
                meta['firmware_verified'] = True
                link.reset_input_buffer()
                target.reset()
                meta['reset_after_verification'] = True
                started = time.monotonic(); mode = ''; mode_started = started
                pending = b''
                while time.monotonic() - started < 20:
                    data = link.read(4096); raw.extend(data); pending += data
                    while b'\n' in pending:
                        line, pending = pending.split(b'\n', 1)
                        words = line.decode(errors='replace').strip('\x00\r ').split()
                        if len(words) > 1 and words[0] == 'LAMPS':
                            candidate = words[1].strip(';')
                            if candidate in MODES and candidate != mode:
                                mode = candidate; mode_started = time.monotonic()
                    now = time.monotonic()
                    # nRF52833 SVD: P0=0x50000000, P1=0x50000300, OUT=+0x504.
                    p0 = target.read32(0x50000504); p1 = target.read32(0x50000804)
                    samples.append({'host_received_utc': utc_now(), 'elapsed_s': now-started,
                                    'mode': mode, 'mode_age_s': now-mode_started,
                                    'brake': (p0 >> 2) & 1, 'left': (p0 >> 12) & 1,
                                    'right': (p1 >> 2) & 1})
                meta['checks'] = validate(raw, samples)
                meta['completed'] = all(meta['checks'].values())
    except Exception as exc:
        meta['error'] = f'{type(exc).__name__}: {exc}'
    finally:
        meta['finished_utc'] = utc_now(); meta['gpio_samples'] = len(samples)
        (args.output/'serial.txt').write_bytes(raw)
        (args.output/'gpio-registers.json').write_text(json.dumps(samples, indent=2))
        (args.output/'capture.json').write_text(json.dumps(meta, indent=2))
        print(json.dumps(meta, indent=2))
    return 0 if meta['completed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
