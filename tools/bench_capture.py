#!/usr/bin/env python3
"""Explicit, bounded bench capture. Lift wheels and keep motor power removable.
Flashes only with --flash. Always requests the firmware stop latch on exit.
This records command flags and MCU state, not physical wheel motion or WCET.
"""
import argparse, importlib.util, json, subprocess, time
from pathlib import Path
import serial
from pyocd.core.helpers import ConnectHelper
repo = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flash', action='store_true')
parser.add_argument('--seconds', type=int, default=15, choices=range(1,61))
parser.add_argument('--port', default='COM5')
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location('mb', repo/'tools/mb.py')
mb = importlib.util.module_from_spec(spec); spec.loader.exec_module(mb)
rc, nm = mb.capture(['alr','exec','--','arm-eabi-nm','-n','build/main.elf'])
if rc: raise SystemExit(nm)
symbols = {name:int(addr,16) for addr,kind,name in
           (line.split() for line in nm.splitlines() if len(line.split())==3)}
for name in ['adaptive_stop_requested','adaptive_motion_commanded','_ada_main']:
    if name not in symbols: raise SystemExit('Required symbol missing: '+name)
options = {'connect_mode':'attach','resume_on_disconnect':False,
           'cache.enable_memory':False,'cache.enable_register':False}
data = b''; states = []
with serial.Serial(args.port,115200,timeout=.1) as port:
    if args.flash:
        result = subprocess.run(['python','-m','pyocd','load','-t','nrf52833',
                  '--format','elf',str(repo/'build/main.elf')],cwd=repo,
                  capture_output=True,text=True,timeout=45)
        (args.output/'flash.txt').write_text(result.stdout+result.stderr)
        result.check_returncode()
    with ConnectHelper.session_with_chosen_probe(target_override='nrf52833',options=options) as session:
        target = session.target
        target.halt()
        target.set_breakpoint(symbols['_ada_main'])
        target.reset_and_halt()
        port.reset_input_buffer()
        target.resume(); time.sleep(.3); target.halt()
        target.remove_breakpoint(symbols['_ada_main'])
        if target.read_core_register('pc') != symbols['_ada_main']:
            raise SystemExit('Did not reach Main; target left halted for investigation.')
        bottom, top = symbols['__stack_start'], symbols['__stack_end']
        fill_end = target.read_core_register('psp') - 128
        target.write_memory_block8(bottom, [0xA5] * (fill_end-bottom))
        target.resume()
        start = time.monotonic()
        try:
            while time.monotonic()-start < args.seconds:
                data += port.read(4096)
                states.append({'elapsed_s':round(time.monotonic()-start,3),
                   'motion_commanded':target.read8(symbols['adaptive_motion_commanded'])})
        finally:
            target.write8(symbols['adaptive_stop_requested'],1)
            # Wait for the sequential code to finish any stationary sensor read.
            until = time.monotonic()+4
            while time.monotonic()<until: data += port.read(4096)
            target.halt()
            memory = bytes(target.read_memory_block8(bottom,fill_end-bottom))
            untouched = next((i for i,b in enumerate(memory) if b != 0xA5),len(memory))
            state = {'registers':{r:hex(target.read_core_register(r)) for r in ['pc','psp','msp','xpsr']},
                'CFSR':hex(target.read32(0xe000ed28)),
                'stack_start':hex(bottom),'stack_end':hex(top),
                'observed_stack_usage_bytes':top-(bottom+untouched),
                'watermark_bottom_untouched_bytes':untouched,
                'stop_requested':target.read8(symbols['adaptive_stop_requested']),
                'motion_commanded':target.read8(symbols['adaptive_motion_commanded']),
                'samples':states}
            (args.output/'state.json').write_text(json.dumps(state,indent=2))
            (args.output/'serial.txt').write_text(data.decode(errors='replace'))
            print(json.dumps({k:v for k,v in state.items() if k!='samples'},indent=2))
            print(data.decode(errors='replace'))
            if state['motion_commanded'] or state['CFSR']!='0x0':
                raise SystemExit('Bench capture failed; remove motor power and inspect logs.')
