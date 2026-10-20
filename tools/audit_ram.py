"""Binary-checked RAM references and reset-to-cartridge-entry snapshots."""
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
from verify_remote import ROM_SHA256

READ={'LDA','LDX','LDY','BIT','CMP','CPX','CPY','ADC','SBC','AND','ORA','EOR'}
WRITE={'STA','STX','STY'}
RMW={'ASL','LSR','ROL','ROR','INC','DEC'}

class Bus(list):
    def __init__(self,rom):
        super().__init__(rom);self.pc=0;self.writes=[]
    def __setitem__(self,address,value):
        if isinstance(address,int) and address<0x800:
            self.writes.append({'pc':f'{self.pc:04X}','address':f'{address:04X}','value':f'{value:02X}'})
        super().__setitem__(address,value)

def startup(rom,warm):
    b=Bus(rom);b[:0x800]=[0xA5]*0x800
    if warm:b[0x100:0x111]=rom[0xE000:0xE011]
    # Synthetic boot header only; no cartridge software executes.
    b[0xB000:0xB006]=[6,0xB0,0x28,0x63,0x29,0x20]
    b.writes=[];m=MPU(memory=b);m.pc=0xE041
    for _ in range(20000):
        if m.pc==0xB006:break
        b.pc=m.pc;m.step()
    else:raise AssertionError(f'No dispatch {m.pc:04X}')
    assert m.p&m.INTERRUPT and m.sp==0xFF
    assert b[0x76:0x78]==[0x14,0xE0]
    assert b[0x100:0x111]==list(rom[0xE000:0xE011])
    assert b[0x600:0x800]==[0xA5]*0x200
    if warm:
        assert b[0x400:0x600]==[0xA5]*0x200
    else:
        assert b[0x400:0x500]==[0]*0x100
        assert b[0x500:0x600]==[0xFF]*0x100
        assert b[0x200]==0xFF
    return {'zero_page':[f'{v:02X}' for v in b[:256]],'ram_writes':b.writes,
            'stack_pointer':f'{m.sp:02X}','IRQ_disabled':bool(m.p&m.INTERRUPT),
            '600_7FF_sentinel_preserved':True,'marker_verified':True}

def analyze(rom,listing):
    assert hashlib.sha256(rom).hexdigest()==ROM_SHA256
    ops=MPU().disassemble;names={op for op,mode in ops if op!='???'}
    positions=set();rejected=[]
    for line in listing.splitlines():
        q=re.match(r'([0-9A-Fa-f]{8}):\s*[0-9A-Fa-f]+\s+(\w+)',line)
        if not q or q[2] not in names:continue
        pc=0xE000+int(q[1],16)
        if ops[rom[pc]][0]!=q[2]:
            rejected.append({'pc':f'{pc:04X}','listed_opcode':q[2],'binary_opcode':ops[rom[pc]][0]});continue
        positions.add(pc)
    # The supplied E555-E573 listing has shifted labels. Decode the entire
    # verified routine linearly from its entry; it contains no inline data.
    positions={pc for pc in positions if not 0xE555<=pc<0xE574}
    decoder=Disassembler(MPU(memory=list(rom)))
    pc=0xE555; recovered=[]
    while pc<0xE574:
        positions.add(pc);recovered.append(f'{pc:04X}')
        length,_=decoder.instruction_at(pc);pc+=length
    assert pc==0xE574
    references=[]
    for pc in sorted(positions):
        op,mode=ops[rom[pc]]
        kind='read' if op in READ else 'write' if op in WRITE else 'read-modify-write' if op in RMW else 'control'
        if mode in ('zpg','zpx','zpy','inx','iny'):
            address=rom[pc+1]
        elif mode in ('abs','abx','aby','ind'):
            address=rom[pc+1]|rom[pc+2]<<8
            if address>=0x800:continue
        else:continue
        references.append({'pc':f'{pc:04X}','opcode':op,'mode':mode,'operand':f'{address:04X}','access':kind})
    assert not any(r['operand']=='00C5' for r in references)
    return {'rom_sha256':ROM_SHA256,'accepted_instruction_locations':len(positions),
            'rejected_listing_opcode_mismatches':rejected,'binary_redecoded_E555_E573':recovered,'RAM_references':references,
            'cold_start':startup(rom,False),'warm_start':startup(rom,True),
            'limits':'Static operands include indexed bases and pointer addresses, not every effective target. Reset trace uses modeled memory and synthetic header, with initial RAM A5; no hardware RAM availability proof.'}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('rom',type=Path);p.add_argument('listing',type=Path);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();report=analyze(a.rom.read_bytes(),a.listing.read_text());a.output.write_text(json.dumps(report,indent=2)+'\n')
    csv_path=a.output.with_suffix('.csv')
    with csv_path.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['pc','opcode','mode','operand','access']);w.writeheader();w.writerows(report['RAM_references'])
