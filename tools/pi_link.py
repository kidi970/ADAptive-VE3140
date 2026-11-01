#!/usr/bin/env python3
"""Find the micro:bit USB link, or passively capture a bounded serial log.

No flashing, resetting, GPIO access or serial commands are implemented here.
Disconnect motor power before connecting USB or opening an unknown firmware.
"""
import argparse
import json
import platform
import time
from datetime import datetime, timezone
from pathlib import Path

MICROBIT_USB = (0x0D28, 0x0204)


def candidates(ports):
    return [p for p in ports if (p.vid, p.pid) == MICROBIT_USB]


def choose(ports, requested=None):
    matches = candidates(ports)
    if requested:
        matches = [p for p in matches if p.device == requested]
    if not matches:
        raise ValueError('Ingen micro:bit funnet. Kontroller USB-datakabelen til Pi-en.')
    if len(matches) != 1:
        raise ValueError('Flere micro:bit-enheter funnet. Velg en med --port.')
    return matches[0]


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def listen(device, output, seconds, serial_factory, monotonic=time.monotonic):
    output.mkdir(parents=True, exist_ok=False)
    meta = {'port': device.device, 'usb_serial': device.serial_number,
            'baud': 115200, 'started_utc': utc_now(), 'capture_completed': False,
            'motor_power_disconnected_reported': True,
            'firmware_identity_verified': False, 'writes_requested': 0,
            'reset_requested': False, 'physical_motion_verified': False}
    received = bytearray()
    try:
        # Set control lines before opening; opening a port can still change
        # line levels on some OS/drivers. Physical motor isolation is required.
        with serial_factory(port=None, baudrate=115200, timeout=0.1,
                            xonxoff=False, rtscts=False, dsrdtr=False,
                            exclusive=True) as link:
            link.dtr = False
            link.rts = False
            link.port = device.device
            link.open()
            started = monotonic()
            with (output / 'receive.jsonl').open('x', encoding='utf-8') as timing:
                while monotonic() - started < seconds:
                    chunk = link.read(1024)
                    if chunk:
                        timing.write(json.dumps({'host_received_utc': utc_now(),
                                     'offset': len(received), 'bytes': len(chunk)}) + '\n')
                        received.extend(chunk)
            meta['elapsed_seconds'] = round(monotonic() - started, 3)
            meta['capture_completed'] = True
    except Exception as exc:
        meta['error'] = f'{type(exc).__name__}: {exc}'
    finally:
        meta['finished_utc'] = utc_now()
        meta['received_bytes'] = len(received)
        (output / 'serial.bin').write_bytes(received)
        (output / 'serial.txt').write_text(received.decode(errors='replace'), encoding='utf-8')
        (output / 'capture.json').write_text(json.dumps(meta, indent=2, ensure_ascii=False),
                                           encoding='utf-8')
    return meta


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    sub.add_parser('status', help='List USB metadata without opening the serial port')
    capture = sub.add_parser('listen', help='Read serial output; never send commands')
    capture.add_argument('--port', help='A detected micro:bit port, for example /dev/ttyACM0')
    capture.add_argument('--seconds', type=int, choices=range(1, 61), default=15,
                         metavar='1..60')
    capture.add_argument('--output', type=Path, required=True, help='New output directory')
    capture.add_argument('--motor-power-disconnected', action='store_true', required=True,
                         help='Record physical isolation of motor power')
    args = parser.parse_args(argv)
    try:
        import serial
        from serial.tools import list_ports
    except ImportError:
        parser.error('pyserial mangler. På Pi OS: sudo apt install python3-serial')
    ports = list(list_ports.comports())
    if args.action == 'status':
        model = Path('/proc/device-tree/model')
        report = {'host': platform.node(),
                  'model': model.read_text().strip('\x00') if model.exists() else platform.machine(),
                  'microbits': [{'port': p.device, 'usb_serial': p.serial_number,
                                'vid': hex(p.vid), 'pid': hex(p.pid)} for p in candidates(ports)],
                  'serial_opened': False}
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0 if report['microbits'] else 1
    try:
        device = choose(ports, args.port)
        meta = listen(device, args.output, args.seconds, serial.Serial)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    print(json.dumps(meta, indent=2, ensure_ascii=False))
    return 0 if meta['capture_completed'] and meta['received_bytes'] > 0 else 1


if __name__ == '__main__':
    raise SystemExit(main())
