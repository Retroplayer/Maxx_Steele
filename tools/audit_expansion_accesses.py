"""Audit listed ROM instructions and trace expansion-related CPU accesses.

Listing locations identify code; instruction bytes and operands come from ROM.
This is not a proof of all possible execution paths or bus-cycle behavior.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from py65.devices.mpu6502 import MPU
from verify_remote import ROM_SHA256

class Bus(list):
    def __init__(self, rom):
        super().__init__(rom)
        self.pc = 0
        self.accesses = []
    def __getitem__(self, address):
        if isinstance(address, int) and 0xC000 <= address <= 0xDFFF:
            self.accesses.append({'pc':f'{self.pc:04X}', 'kind':'read', 'address':f'{address:04X}'})
        return super().__getitem__(address)
    def __setitem__(self, address, value):
        if isinstance(address, int) and 0xC000 <= address <= 0xDFFF:
            self.accesses.append({'pc':f'{self.pc:04X}', 'kind':'write', 'address':f'{address:04X}', 'value':f'{value:02X}'})
        super().__setitem__(address, value)

def run(bus, entry, stop=0x7FFF, a=0, y=0):
    cpu=MPU(memory=bus); cpu.pc, cpu.a, cpu.y, cpu.sp=entry,a,y,0xFD
    cpu.p &= ~8
    bus[0x1FE:0x200]=[0xFE,0x7F]
    for _ in range(2000):
        if cpu.pc==stop: return cpu
        bus.pc=cpu.pc; cpu.step()
    raise AssertionError(f'No stop at {cpu.pc:04X}')

def analyze(rom, listing):
    assert hashlib.sha256(rom).hexdigest()==ROM_SHA256
    ops=MPU().disassemble; names={name for name, mode in ops if name!='???'}
    positions=set()
    for line in listing.splitlines():
        m=re.match(r'([0-9A-Fa-f]{8}):\s*[0-9A-Fa-f]+\s+(\w+)',line)
        if m and m[2] in names: positions.add(0xE000+int(m[1],16))
    operands=[]; indirect=[]
    for pc in sorted(positions):
        op,mode=ops[rom[pc]]
        if mode in ('abs','abx','aby','ind'):
            address=rom[pc+1]|rom[pc+2]<<8
            # Include indexed bases below C000 that could cross into it.
            if 0xC000<=address<0xE000 or (mode in ('abx','aby') and 0xBF01<=address<0xC000):
                operands.append({'pc':f'{pc:04X}','opcode':op,'mode':mode,'operand':f'{address:04X}'})
        if mode in ('inx','iny','ind'):
            indirect.append({'pc':f'{pc:04X}','opcode':op,'mode':mode,'pointer':f'{rom[pc+1]:02X}'})
    assert operands==[{'pc':'E09F','opcode':'CMP','mode':'aby','operand':'DFFE'}]
    b=Bus(rom); b[0x8E:0x90]=[0,0x10]; b[0xB000:0xB006]=[0,0x60,0x28,0x63,0x29,0x20]
    cpu=MPU(memory=b);cpu.pc=0xE090; ys=[];compares=[]
    for _ in range(1000):
        if cpu.pc==0x6000:break
        if cpu.pc==0xE09F:
            ys.append(cpu.y);compares.append(f'{(0xDFFE+cpu.y)&65535:04X}')
        b.pc=cpu.pc;cpu.step()
    assert cpu.pc==0x6000 and set(ys)=={2,3,4,5} and not b.accesses
    b=Bus(rom);b[0x0F:0x11]=[0x80,0xBF];b[0xC000:0xC002]=[1,7]
    run(b,0xE519)
    assert b[0x11]==1 and b[0x13]==7
    read_trace=b.accesses.copy()
    b.accesses=[];b[0x13]=9
    run(b,0xE335,stop=0xF64E,a=2,y=0x80)
    assert b[0xC000:0xC002]==[2,9] and b[0x0F:0x11]==[0x82,0xBF]
    tunes=[]
    for index in range(9):
        pointer=rom[0xFDEC+index]|rom[0xFDF5+index]<<8
        targets=[rom[pointer+j]|rom[pointer+j+1]<<8 for j in (0,2,4)]
        assert all(not 0xC000<=value<0xE000 for value in targets)
        tunes.append({'index':index,'header':f'{pointer:04X}','voices':[f'{v:04X}' for v in targets]})
    return {'rom_sha256':ROM_SHA256,'listed_instruction_locations_audited':len(positions),
            'stock_tune_pointers':tunes,'absolute_operand_candidates':operands,'indirect_instructions':indirect,
            'boot_scan':{'compare_Y_values':sorted(set(ys)), 'compare_effective_addresses':sorted(set(compares)),
                         'architectural_C000_DFFF_accesses':[],'matching_header_base':'B000'},
            'synthetic_relocated_cursor':{'cursor':'BF80','fetch':read_trace,'store':b.accesses},
            'limits':'Listing identifies code locations. Modeled RAM and altered cursor demonstrate routines only. py65 does not model NMOS page-cross dummy bus reads or ASIC address decoding.'}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('rom',type=Path);p.add_argument('listing',type=Path);p.add_argument('--output',type=Path)
    args=p.parse_args();report=analyze(args.rom.read_bytes(),args.listing.read_text())
    output=json.dumps(report,indent=2)+'\n'
    if args.output:args.output.write_text(output)
    else:print(output)
