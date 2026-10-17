#!/usr/bin/env python3
"""Compare actual C++ encoder output with capture fixtures and the ROM decoder."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from verify_remote import Receiver, ROM_SHA256
sys.path.insert(0,str(ROOT/'pico'))
import protocol

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom',type=Path,required=True)
    args=parser.parse_args()
    rom=args.rom.read_bytes()
    assert hashlib.sha256(rom).hexdigest()==ROM_SHA256
    with tempfile.TemporaryDirectory() as folder:
        exe=str(Path(folder)/'encoder')
        subprocess.run(['g++','-std=c++11','-Wall','-Wextra','-Werror',str(ROOT/'remote-avr/tests/controller_test.cpp'),'-o',exe],check=True)
        rows=subprocess.check_output([exe,'--frames'],text=True).splitlines()
    frames={}
    for row in rows:
        key,release,code,bits=map(int,row.split())
        assert code==protocol.encode(key,bool(release))
        sequence=f'{bits:011b}'
        assert sequence==''.join(map(str,protocol.symbols(code)))
        frames[key,release]=(code,sequence)
    captures=json.loads((ROOT/'docs/remote-capture-verification.json').read_text())
    for capture in captures['captures']:
        key=capture['key_id']
        for value in capture['code_counts']:
            assert int(value,16) in (frames[key,0][0],frames[key,1][0])
    # Feed C++-generated symbols with nominal transmitter timing, sampling every
    # 528 us as in the existing accepted capture replay (not measured ASIC IRQ).
    for key in range(1,26):
        r=Receiver(rom)
        stream=[frames[key,0][1],frames[key,0][1],frames[key,1][1]]
        events=[]
        for t in range(0,3*protocol.FRAME_PERIOD_US,528):
            f=t//protocol.FRAME_PERIOD_US
            symbol=(t%protocol.FRAME_PERIOD_US)//protocol.SYMBOL_US
            r.tick(int(stream[f][symbol]) if symbol<11 else 0)
            event=r.take()
            if event!=0x80: events.append(event)
            if r.stopped: break
        assert r.mem[0xa1]==r.mem[0xa2]==0
        if key==25: assert r.stopped
        else: assert events==[key-1,key-1+0x20], (key,events)
    print('PASS: all 50 AVR codes/symbol strings match Python encoder; all 23 capture code sets agree; all 25 nominal-timing press/repeat/release sequences accepted by original ROM')
if __name__=='__main__': main()
