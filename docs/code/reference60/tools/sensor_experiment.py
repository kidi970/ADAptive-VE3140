#!/usr/bin/env python3
"""Capture stationary diagnostics with motor power physically disconnected.

Only diagnostic images can be selected. --reset verifies existing flash before
resetting; --flash programs and verifies the selected diagnostic before reset.
No action is inferred from silence on COM5. Each output directory must be new.
"""
import argparse
import hashlib
import json
import time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
IMAGE = REPO / 'build/sensor-diagnostic/Code/diagnostics/obj/sensor_diagnostic'
GPIO_IMAGE = REPO / 'build/sensor-diagnostic/Code/diagnostics/obj-gpio/sensor_gpio_diagnostic'
HEADER = 'seq,phase,sensor,t_us,interval_ms,trigger_gap_us,status,pulse_us,elapsed_us,distance_milli_cm,legacy_cm'
PROFILES = {
    'v2': ('ADAptive SENSOR DIAGNOSTIC v2; MOTION DISABLED; RISE_TIMEOUT_US=10000',
           'DONE,320,MOTION_DISABLED'),
    'gpio-v3': ('ADAptive SENSOR GPIO DIAGNOSTIC v3; NO_MOTOR_WRITES; RISE_TIMEOUT_US=10000',
                'DONE,320,NO_MOTOR_WRITES'),
}


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def validate_capture(raw, rows, profile):
    """A DONE marker alone cannot certify a complete, correctly ordered run."""
    banner, done = PROFILES[profile]
    lines = [line.strip('\x00\r ') for line in raw.decode(errors='replace').splitlines()]
    expected = ([(phase, sensor) for phase in ('ALL_65', 'ALL_100')
                 for _ in range(40) for sensor in 'FLR']
                + [(phase, 'L') for phase in ('LEFT_65', 'LEFT_100') for _ in range(40)])
    data_positions = [i for i, line in enumerate(lines) if line.startswith('DATA,')]
    return (lines.count(banner) == 1 and lines.count(done) == 1
            and not any('DIAGNOSTIC FAULT' in line for line in lines)
            and len(data_positions) == 320
            and [(r['phase'], r['sensor']) for r in rows] == expected
            and [r['seq'] for r in rows] == list(range(1, 321))
            and lines.index(banner) < data_positions[0]
            and lines.index(done) > data_positions[-1])


def verify_image(target, image):
    from elftools.elf.elffile import ELFFile
    segments = []
    # Compare flash load addresses, including the initial RAM data in flash.
    # Small synchronous reads avoid the observed CMSIS-DAP v2 bulk timeout.
    with image.open('rb') as file:
        for segment in ELFFile(file).iter_segments():
            if segment['p_type'] != 'PT_LOAD' or not segment['p_filesz']:
                continue
            address = segment['p_paddr']
            if address >= 0x80000:
                continue
            data = segment.data()
            if address + len(data) > 0x80000:
                raise ValueError('Diagnostic segment exceeds nRF52833 flash')
            actual = bytearray()
            for offset in range(0, len(data), 256):
                actual.extend(target.read_memory_block8(address + offset, min(256, len(data)-offset)))
            segments.append({'address': address, 'bytes': len(data), 'matches': actual == data,
                             'flash_sha256': hashlib.sha256(actual).hexdigest(),
                             'elf_segment_sha256': hashlib.sha256(data).hexdigest()})
    if not segments or not all(s['matches'] for s in segments):
        raise ValueError('Flash does not match selected diagnostic; reset refused')
    return segments


def main():
    import serial
    from analyze_sensors import read_samples
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--flash', action='store_true')
    action.add_argument('--reset', action='store_true')
    parser.add_argument('--gpio-only', action='store_true')
    parser.add_argument('--motor-power-disconnected', action='store_true',
                        help='Record the already physically confirmed motor-power isolation')
    parser.add_argument('--probe-id', help='Require this CMSIS-DAP probe ID')
    parser.add_argument('--port', default='COM5')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--context', required=True, help='Actual setup and provenance of reference distances')
    args = parser.parse_args()
    if not args.motor_power_disconnected:
        parser.error('Motor power must be physically disconnected; record it with --motor-power-disconnected')
    image = GPIO_IMAGE if args.gpio_only else IMAGE
    profile = 'gpio-v3' if args.gpio_only else 'v2'
    if not image.is_file():
        parser.error('Build the selected diagnostic first')
    args.output.mkdir(parents=True, exist_ok=False)
    meta = {'image': str(image), 'sha256': hashlib.sha256(image.read_bytes()).hexdigest(),
            'profile': profile, 'port': args.port, 'baud': 115200, 'bytesize': 8,
            'parity': 'N', 'stopbits': 1, 'flow_control': False,
            'context': args.context, 'motor_power_disconnected_reported': True,
            'flash_requested': args.flash, 'reset_requested': args.reset,
            'started_utc': utc_now(), 'completed': False,
            'firmware_verified': False, 'local_image_hash_is_not_running_firmware_proof': True}
    raw = bytearray()
    chunks = []
    try:
        with serial.Serial(args.port, 115200, bytesize=8, parity='N', stopbits=1,
                           timeout=.1, xonxoff=False, rtscts=False, dsrdtr=False) as port:
            port.reset_input_buffer()
            if args.flash or args.reset:
                from pyocd.core.helpers import ConnectHelper
                from pyocd.flash.file_programmer import FileProgrammer
                options = {'connect_mode': 'attach', 'resume_on_disconnect': False,
                           'cmsis_dap.prefer_v1': True, 'cmsis_dap.limit_packets': True,
                           'cmsis_dap.deferred_transfers': False}
                with ConnectHelper.session_with_chosen_probe(
                        unique_id=args.probe_id, target_override='nrf52833', options=options,
                        blocking=False, return_first=False) as session:
                    meta['probe_id'] = session.probe.unique_id
                    if args.flash:
                        FileProgrammer(session).program(str(image), file_format='elf')
                    meta['flash_segments'] = verify_image(session.target, image)
                    meta['firmware_verified'] = True
                    # Reset only after byte verification; never resume an unknown image.
                    session.target.reset()
            start = time.monotonic()
            while time.monotonic() - start < 60:
                data = port.read(1024)
                if data:
                    chunks.append({'received_utc': utc_now(), 'offset': len(raw), 'bytes': len(data)})
                    raw.extend(data)
                if PROFILES[profile][1].encode() in raw or b'DIAGNOSTIC FAULT' in raw:
                    break
            meta['capture_seconds'] = round(time.monotonic() - start, 3)
    except Exception as exc:
        meta['error'] = f'{type(exc).__name__}: {exc}'
    finally:
        (args.output / 'serial.txt').write_bytes(raw)
        (args.output / 'host-receive-times.json').write_text(json.dumps(chunks, indent=2), encoding='utf-8')
        lines = [line[5:].strip() for line in raw.decode(errors='replace').splitlines()
                 if line.startswith('DATA,')]
        path = args.output / 'samples.csv'
        path.write_text(HEADER + '\n' + '\n'.join(lines) + '\n', encoding='utf-8')
        meta['data_rows'] = len(lines)
        try:
            rows = read_samples(path)
            meta['completed'] = validate_capture(raw, rows, profile) and meta.get('error') is None
            meta['left_rows'] = sum(r['sensor'] == 'L' for r in rows)
        except ValueError as exc:
            meta['validation_error'] = str(exc)
        meta['finished_utc'] = utc_now()
        (args.output / 'capture.json').write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding='utf-8')
        print(json.dumps(meta, indent=2, ensure_ascii=False))
    return 0 if meta['completed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
