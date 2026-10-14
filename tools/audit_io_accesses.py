"""Inventory original ROM I/O operands using listed instruction locations.

The binary supplies opcodes and operands. This does not infer ASIC mirroring
or prove absence of accesses through modified/corrupt indirect pointers.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from py65.devices.mpu6502 import MPU
from verify_remote import ROM_SHA256

READ={'LDA','LDX','LDY','BIT','CMP','CPX','CPY','ADC','SBC','AND','ORA','EOR'}
WRITE={'STA','STX','STY'}
RMW={'ASL','LSR','ROL','ROR','INC','DEC'}

def analyze(rom, listing):
    assert hashlib.sha256(rom).hexdigest()==ROM_SHA256
    ops=MPU().disassemble; names={op for op,mode in ops if op!='???'}
    positions=set()
    for line in listing.splitlines():
        m=re.match(r'([0-9A-Fa-f]{8}):\s*[0-9A-Fa-f]+\s+(\w+)',line)
        if m and m[2] in names:positions.add(0xE000+int(m[1],16))
    accesses=[]; indirect=[]; crossing=[]
    for pc in sorted(positions):
        opcode,mode=ops[rom[pc]]
        if mode in ('abs','abx','aby'):
            address=rom[pc+1]|rom[pc+2]<<8
            if mode in ('abx','aby') and 0x0F01<=address<0x1000:
                crossing.append({'pc':f'{pc:04X}','opcode':opcode,'base':f'{address:04X}'})
            if 0x1000<=address<0x2000:
                kind='read' if opcode in READ else 'write' if opcode in WRITE else 'read-modify-write' if opcode in RMW else 'control-transfer'
                accesses.append({'pc':f'{pc:04X}','opcode':opcode,'mode':mode,
                                 'address':f'{address:04X}','access':kind,'cpu_data_width_bits':8})
        if mode in ('inx','iny','ind'):
            indirect.append({'pc':f'{pc:04X}','opcode':opcode,'mode':mode,'pointer':f'{rom[pc+1]:02X}'})
    registers=[]
    for address in sorted({x['address'] for x in accesses}):
        sites=[x for x in accesses if x['address']==address]
        registers.append({'address':address,'read_sites':[x['pc'] for x in sites if x['access']=='read'],
                          'write_sites':[x['pc'] for x in sites if x['access']=='write'],
                          'read_modify_write_sites':[x['pc'] for x in sites if x['access']=='read-modify-write']})
    assert [r['address'] for r in registers]==['1000','1200','1400','1600','1C00','1E00']
    assert len(accesses)==43 and not crossing
    assert all(x['mode']=='abs' and x['access'] in ('read','write') for x in accesses)
    return {'rom_sha256':ROM_SHA256,'listed_instruction_locations_audited':len(positions),
            'access_site_count':len(accesses),'registers':registers,'accesses':accesses,
            'indexed_bases_below_1000_that_could_cross_into_io':crossing,
            'indirect_instructions_for_manual_pointer_review':indirect,
            'limits':'Static instruction-site counts, not dynamic access counts. No ASIC decode/alias or internal register width inference. Listing identifies code; binary supplies opcodes/operands.'}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('rom',type=Path);p.add_argument('listing',type=Path);p.add_argument('--output',type=Path)
    args=p.parse_args();output=json.dumps(analyze(args.rom.read_bytes(),args.listing.read_text()),indent=2)+'\n'
    if args.output:args.output.write_text(output)
    else:print(output)
