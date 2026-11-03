#!/usr/bin/env python3
"""Build/capture isolated micro:bit tests; never select autonomous main.elf.

Use a micro:bit v2 detached from the car. The components image also requires
the documented bench wiring. --flash is explicit and verifies flash before
reset. An absent USB device is recorded as a failure, never simulated evidence.
"""
import argparse
import json
import struct
import time
from datetime import datetime, timezone
from pathlib import Path
import mb
from analyze_sensors import STATUSES
from diagnostic_guard import image_hash, preflight, verify_probe
from pi_link import choose
from sensor_experiment import verify_image

REPO = Path(__file__).resolve().parents[1]
PROFILES = {
    'usb': ('standalone_usb', 'obj-usb', 'ADAptive USB SELFTEST v1; NO_MOTOR_WRITES; NO_I2C',
            'DONE,USB_SELFTEST,12'),
    'components': ('standalone_components', 'obj-components',
                   'ADAptive COMPONENT BENCH v1; NO_MOTOR_WRITES; MATRIX_DISABLED',
                   'DONE,COMPONENT_BENCH,15,135'),
}


def image_path(profile):
    name, directory, _, _ = PROFILES[profile]
    return REPO / f'build/standalone/Code/bench/{directory}/{name}'


def link_check(path, profile):
    from audit_firmware import inspect_elf
    symbols = [name.lower() for name in inspect_elf(Path(path).read_bytes(),
                                                  include_symbols=True)['symbols']]
    forbidden = ['adaptive_motion', 'dfr0548', 'microbit__motors', 'microbit__servo',
                 'adaptive_navigation', 'adaptive_controller']
    if profile == 'usb':
        forbidden += ['microbit__i2c', 'nrf__twi', 'hal__i2c', 'adaptive_echo', 'microbit__ultrasonic',
                      'adaptive_sensors', 'adaptive_bench_oled', 'adaptive_oled_codec',
                      'adaptive_display', 'ssd1306']
    else:
        forbidden += ['microbit__displayrt']
    bad = [name for name in symbols if any(token in name for token in forbidden)]
    if bad:
        raise ValueError('Unexpected linked dependency: ' + ', '.join(bad[:12]))
    return {'profile': profile, 'forbidden_symbols': bad, 'passed': True,
            'meaning': 'Linked-image inspection; not an electrical measurement or a physical isolation check.'}


def component_summary(events):
    """Check protocol consistency against v1's three-sample bench indication.

    The on-device model uses IEEE binary32 pulse/58 distances. Reconstruct that
    value, including subtraction rounding at the 15 cm stability boundary.
    This is log validation, not an independent physical correctness proof.
    """
    def f32(value):
        return struct.unpack('<f', struct.pack('<f', value))[0]
    windows = []
    texts = []
    for index in range(0, 9, 3):
        group = events[index:index + 3]
        if any(fields[3] != 'VALID_ECHO' for fields in group):
            windows.append(None); texts.append('UNKNOWN'); continue
        values = [f32(int(fields[4]) / 58.0) for fields in group]
        if f32(max(values) - min(values)) > 15.0:
            windows.append(None); texts.append('UNSTABLE'); continue
        windows.append(min(values)); texts.append(f'{int(min(values))} CM')
    if any(value is None for value in windows): state = 'UNKNOWN'
    elif windows[0] <= 45 or windows[1] <= 15 or windows[2] <= 15: state = 'STOP'
    elif windows[0] <= 60 or windows[1] <= 30 or windows[2] <= 30: state = 'CAUTION'
    else: state = 'CLEAR'
    return state, texts


def trigger_times_valid(timestamps):
    # Trigger scheduling is at least 65 ms; allow one microsecond for integer
    # timestamp conversion. Equal/near-zero gaps cannot represent this image.
    return all(b-a >= 64_999 for a,b in zip(timestamps,timestamps[1:]))


def validate(raw, profile):
    lines = [line.strip('\x00\r ') for line in raw.decode(errors='replace').splitlines()]
    _, _, banner, done = PROFILES[profile]
    if lines.count(banner) != 1 or lines.count(done) != 1:
        return False
    if any('FAULT' in line for line in lines):
        return False
    if profile == 'usb':
        events = [line for line in lines if line.startswith('TICK,')]
        expected = range(1, 13)
        try:
            if [int(line.split(',')[1]) for line in events] != list(expected):
                return False
            if any(len(line.split(',')) != 4 or
                   line.split(',')[2].strip() not in ('A=PRESSED','A=RELEASED') or
                   line.split(',')[3].strip() not in ('B=PRESSED','B=RELEASED')
                   for line in events):
                return False
        except (ValueError, IndexError):
            return False
        model_line = 'MODEL,PASS,PULSE_US=3480,NOMINAL_CM=60; NOT_A_SENSOR_MEASUREMENT'
        if lines.count(model_line) != 1 or lines.index(model_line) > lines.index(events[0]):
            return False
    else:
        events = [line for line in lines if line.startswith('RAW,')]
        frames = [line for line in lines if line.startswith('FRAME,')]
        expected_sensors = [sensor for _ in range(15) for sensor in 'FLR' for _ in range(3)]
        try:
            if [int(line.split(',')[1]) for line in events] != list(range(1,136)):
                return False
            if [line.split(',')[2].strip() for line in events] != expected_sensors:
                return False
            if [int(line.split(',')[1]) for line in frames] != list(range(1,16)):
                return False
            timestamps=[]; parsed=[]
            for event in events:
                fields=[field.strip() for field in event.split(',')]
                if len(fields) != 8 or fields[3] not in STATUSES:
                    return False
                pulse,elapsed,distance,stamp=map(int,fields[4:])
                if min(pulse,elapsed,distance,stamp) < 0 or pulse > elapsed:
                    return False
                if fields[3]=='VALID_ECHO' and (not 2000 <= distance <= 200000
                        or abs(distance*58/1000-pulse) > 1):
                    return False
                timestamps.append(stamp)
                parsed.append(fields)
            if not trigger_times_valid(timestamps):
                return False
            oled_failed = False
            for index, frame in enumerate(frames):
                fields=[field.strip() for field in frame.split(',')]
                if len(fields)!=7 or fields[2] not in ('UNKNOWN','STOP','CAUTION','CLEAR'):
                    return False
                if fields[3] not in ('OLED=FALSE','OLED=TRUE'):
                    return False
                if fields[3] == 'OLED=FALSE': oled_failed = True
                elif oled_failed: return False
                state, texts = component_summary(parsed[index*9:index*9+9])
                if fields[2] != state:
                    return False
                for field, sensor, text in zip(fields[4:], 'FLR', texts):
                    if '=' not in field: return False
                    key, value = field.split('=', 1)
                    if key != sensor or value.strip() != text: return False
        except (ValueError, IndexError):
            return False
        ordered = [line for line in lines if line.startswith(('RAW,','FRAME,'))]
        # Each frame must follow its own nine samples, never stale/early data.
        if ordered != [event for i in range(15) for event in [*events[i*9:i*9+9],frames[i]]]:
            return False
    return (lines.index(banner) < lines.index(events[0])
            and lines.index(done) > lines.index(events[-1])
            and (profile == 'usb' or lines.index(done) > lines.index(frames[-1])))


def build(profile):
    name = PROFILES[profile][0]
    rc = mb.alr_exec(['gprbuild','-p','-P',f'Code/bench/{name}.gpr',
                      '--root-dir=.','--relocate-build-tree=build/standalone'])
    if rc:
        return rc
    check = link_check(image_path(profile), profile)
    print(json.dumps(check, indent=2))
    # Additional .hex output supports the standard MICROBIT drive fallback.
    return mb.alr_exec(['arm-eabi-objcopy','-O','ihex',str(image_path(profile)),
                       str(REPO/f'build/standalone/{profile}.hex')])


def capture(args, *, hardware=None):
    path = args.output
    path.mkdir(parents=True, exist_ok=False)
    meta = {'profile':args.profile,'started_utc':datetime.now(timezone.utc).isoformat(),
            'detached_from_car_reported':args.detached_from_car,'flash_requested':args.flash,
            'completed':False,'firmware_verified':False}
    raw = bytearray()
    try:
        if not args.detached_from_car:
            raise ValueError('Detach micro:bit from the car before this bench test')
        image = image_path(args.profile)
        meta['image'] = str(image)
        prerequisites = preflight(image, args.image_sha256, args.probe_id,
                                  flash=args.flash, backup=args.backup)
        meta['preflight'] = prerequisites
        meta['image_sha256'] = prerequisites['image_sha256']
        meta['link_check'] = link_check(image, args.profile)
        if not args.port:
            raise ValueError('Capture requires an explicit --port')
        if hardware is None:
            import serial
            from serial.tools import list_ports
            if args.flash:
                from pyocd.core.helpers import ConnectHelper
                from pyocd.flash.file_programmer import FileProgrammer
                hardware = (serial.Serial, list_ports.comports,
                            ConnectHelper.session_with_chosen_probe, FileProgrammer)
            else:
                hardware = (serial.Serial, list_ports.comports, None, None)
        serial_factory, ports_factory, session_factory, programmer_factory = hardware
        device = choose(list(ports_factory()), args.port)
        if not device.serial_number or device.serial_number.lower() != args.probe_id.lower():
            raise ValueError('Serial device differs from the explicit --probe-id')
        port_name = device.device
        meta['port'] = port_name
        chosen = None
        if args.flash:
            options = {'connect_mode':'attach','resume_on_disconnect':False,
                       'auto_unlock':False,
                       'cmsis_dap.prefer_v1':True,'cmsis_dap.limit_packets':True,
                       'cmsis_dap.deferred_transfers':False}
            chosen = session_factory(unique_id=args.probe_id, target_override='nrf52833',
                                     options=options, blocking=False, return_first=False)
            verify_probe(chosen, args.probe_id)
        with serial_factory(port=None,baudrate=115200,timeout=.1,
                            xonxoff=False,rtscts=False,dsrdtr=False) as port:
            port.dtr = False; port.rts = False; port.port = port_name; port.open()
            if args.flash:
                meta['probe_id'] = args.probe_id
                with chosen as session:
                    image_hash(image, args.image_sha256)
                    session.target.reset_and_halt()
                    programmer_factory(session, no_reset=True).program(str(image), file_format='elf')
                    meta['flash_segments'] = verify_image(session.target,image)
                    meta['firmware_verified'] = True
                    port.reset_input_buffer()
                    session.target.reset()
            start = time.monotonic()
            while time.monotonic()-start < 45:
                raw.extend(port.read(1024))
                if PROFILES[args.profile][3].encode() in raw or b'_FAULT,' in raw:
                    break
            meta['capture_seconds'] = round(time.monotonic()-start,3)
            meta['completed'] = validate(raw,args.profile) and 'error' not in meta
            if args.profile=='components':
                lines=raw.decode(errors='replace').splitlines()
                meta['valid_echo_count'] = sum(line.startswith('RAW,') and ',VALID_ECHO,' in line for line in lines)
                meta['oled_ready_frames'] = sum(line.startswith('FRAME,') and ',OLED=TRUE,' in line for line in lines)
            meta['physical_led_visual_confirmation'] = 'not independently observed'
            # A serial-only capture never proves which image was running.
    except Exception as exc:
        meta['error'] = type(exc).__name__ + ': ' + str(exc)
    finally:
        (path/'serial.txt').write_bytes(raw)
        meta['finished_utc'] = datetime.now(timezone.utc).isoformat()
        (path/'capture.json').write_bytes(json.dumps(meta,indent=2,ensure_ascii=False).encode())
        print(json.dumps(meta,indent=2,ensure_ascii=False))
    return 0 if meta['completed'] else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=('build','capture','probe'))
    parser.add_argument('--profile',choices=PROFILES,required=True)
    parser.add_argument('--flash',action='store_true')
    parser.add_argument('--detached-from-car',action='store_true')
    parser.add_argument('--output',type=Path)
    parser.add_argument('--port',help='Explicit micro:bit USB serial port for capture')
    parser.add_argument('--probe-id',help='Exact expected probe/UART serial ID for capture')
    parser.add_argument('--image-sha256',help='Expected SHA-256 of the selected standalone ELF')
    parser.add_argument('--backup',type=Path,help='Matching double-read flash/UICR backup; required for --flash')
    args = parser.parse_args(argv)
    if args.flash and args.action != 'capture':
        parser.error('--flash is valid only for capture; build never accesses a device')
    if args.action == 'probe':
        from serial.tools import list_ports
        from pyocd.core.helpers import ConnectHelper
        ports=list(list_ports.comports())
        probes=ConnectHelper.get_all_connected_probes(blocking=False)
        result={'observed_utc':datetime.now(timezone.utc).isoformat(),
                'serial_ports':[port.device for port in ports],
                'microbit_ports':[port.device for port in ports if port.vid==0x0D28],
                'debug_probe_count':len(probes),
                'physical_test_started':False}
        if args.output:
            args.output.parent.mkdir(parents=True,exist_ok=True)
            with args.output.open('xb') as file:
                file.write(json.dumps(result,indent=2).encode())
        print(json.dumps(result,indent=2))
        return 0 if result['microbit_ports'] and probes else 1
    if args.action == 'build':
        return build(args.profile)
    if args.output is None:
        parser.error('Capture requires a new --output directory')
    if not args.port or not args.probe_id or not args.image_sha256:
        parser.error('Capture requires --port, --probe-id and --image-sha256')
    return capture(args)


if __name__ == '__main__':
    raise SystemExit(main())
