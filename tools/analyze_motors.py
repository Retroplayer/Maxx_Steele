"""Execute original motor routines with explicitly modeled COP replies."""
import argparse
import hashlib
import json
from pathlib import Path
from py65.devices.mpu6502 import MPU
from verify_remote import ROM_SHA256

class Bus(list):
    def __init__(self, rom):
        super().__init__(rom)
        self.pc = self.clock = self.bit = 0
        self.reply = 0
        self.writes = []
    def __getitem__(self, address):
        if address == 0x1000:
            self.clock ^= 0x40
            data = 0
            if self.pc == 0xED91:
                data = ((self.reply ^ 255) >> (7-self.bit)) & 1
                self.bit += 1
            return 0x80 | self.clock | data
        return super().__getitem__(address)
    def __setitem__(self, address, value):
        if address == 0x1200:
            self.writes.append((self.pc, value))
        super().__setitem__(address, value)

class Trace:
    def __init__(self, rom, ram=None, replies=None):
        self.bus = Bus(rom)
        self.cpu = MPU(memory=self.bus)
        for address, value in (ram or {}).items():
            self.bus[address] = value
        self.replies = replies or {}
    def run(self, entry, a=0, stops=()):
        m, b = self.cpu, self.bus
        m.pc, m.a, m.sp = entry, a, 0xFD
        m.p &= ~8
        b[0x1FE:0x200] = [0xFE, 0x7F]
        sent, queries = [], []
        for _ in range(50000):
            if m.pc in (0x7FFF, *stops):
                break
            if m.pc == 0xED7B:
                b.reply, b.bit = self.replies.get(m.a, 0), 0
                queries.append(m.a)
            if m.pc == 0xED55:
                sent.append(m.a)
            b.pc = m.pc
            m.step()
        else:
            raise AssertionError(f'No return at {m.pc:04X}')
        bits = [v & 1 for pc, v in b.writes if pc == 0xED69]
        assert len(bits) == 8 * len(sent)
        for i, value in enumerate(sent):
            assert sum(bits[i*8+j] << (7-j) for j in range(8)) == value
        return {'sent': [f'{v:02X}' for v in sent],
                'queries': [f'{v:02X}' for v in queries], 'stop': f'{m.pc:04X}'}

def analyze(rom):
    for reply in range(256):
        t = Trace(rom, replies={0x84: reply})
        t.run(0xED7B, 0x84)
        assert t.cpu.a == reply and t.bus.bit == 8
        assert [v for pc,v in t.bus.writes if pc == 0xED89] == [0xF4]*8
        assert [v for pc,v in t.bus.writes if pc == 0xED99] == [0xF0]*8
    expected = [[0xD5,3,0x95,7], [0xD3,3,0x93,7], [0xE3,3,0xA3,7],
                [0xD4,3,0x94,7], [0x92,7], [0xA2,7], [0x91,7],
                [0xA1,7], [0xA0,7], [0x70]]
    motions = []
    for opcode, values in enumerate(expected):
        t = Trace(rom, {0x13:7})
        r = t.run(0xE9FE, opcode)
        assert r['sent'] == [f'{v:02X}' for v in values], r
        r.update(opcode=f'{opcode:02X}', status05=f'{t.bus[5]:02X}', status08=f'{t.bus[8]:02X}')
        motions.append(r)
    variants = []
    for opcode, ram, values in [(0,{7:1},[0xE5,3,0xA5,7]),
                               (3,{7:1},[0xE4,3,0xA4,7]),
                               (9,{0x13:0},[0x50])]:
        t=Trace(rom,{0x13:7,**ram}); r=t.run(0xE9FE,opcode)
        assert r['sent']==[f'{v:02X}' for v in values]
        variants.append(r)
    for opcode, mask in [(4,0x40),(5,0x80),(6,0x40),(7,0x80)]:
        t=Trace(rom,{0x13:7,9:mask}); assert not t.run(0xE9FE,opcode)['sent']
    coupling=[]
    for opcode in (6,7):
        for flag in (0,1):
            t=Trace(rom,{0x13:7,3:flag}); t.run(0xE9FE,opcode)
            assert t.bus[5] == {(6,0):0x60,(6,1):0x40,(7,0):0x90,(7,1):0x80}[opcode,flag]
            coupling.append({'opcode':opcode,'flag':flag,'status05':f'{t.bus[5]:02X}'})
    polls=[]
    for same in (False,True):
        t=Trace(rom,{0x0B:0x55,0x0C:8,0x19:1,0x1C:1,0x1F:1,0x22:1},
                {0xB0:0x55,0xB1:8,0x84:1 if same else 2,0x82:2,0x81:2,0x80:2})
        r=t.run(0xEDAF,stops=(0xEE2F,0xEE1C))
        assert r['stop']==('EE1C' if same else 'EE2F')
        assert r['queries']==(['B1','B0','84'] if same else ['B1','B0','84','82','81','80'])
        polls.append(r)
    completions=[]
    for entry,request,pos,old,flag in [(0xECC5,0x44,0x18,0x1A,1),
        (0xECD4,0x42,0x1B,0x1D,0x10),(0xECE3,0x41,0x1E,0x20,0x40),
        (0xECF2,0x40,0x21,0x23,0)]:
        t=Trace(rom,{pos:20,old:3,7:flag},{request:5})
        r=t.run(entry)
        assert r['queries']==[f'{request:02X}']
        assert t.bus[pos]==(18 if request!=0x40 else 22)
        assert t.bus[old]==0
        completions.append({**r,'position':t.bus[pos]})
    return {'rom_sha256':ROM_SHA256,'reply_values_tested':256,'motions':motions,
            'variants':variants,'coupling':coupling,'polls':polls,'completions':completions,
            'model':'Synthetic clock and COP replies; ready bit high; no COP firmware emulation.'}

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('rom',type=Path); p.add_argument('--output',type=Path)
    args=p.parse_args(); rom=args.rom.read_bytes()
    assert hashlib.sha256(rom).hexdigest()==ROM_SHA256
    result=analyze(rom); output=json.dumps(result,indent=2)+'\n'
    if args.output: args.output.write_text(output)
    else: print(output)
