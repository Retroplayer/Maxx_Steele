"""Functional 6502 payload check and compiled ARM image sanity checks.
Requires py65==1.2.0; does not simulate the electrical bus timing.
"""
import argparse,hashlib,json,struct,subprocess
from pathlib import Path
from py65.devices.mpu6502 import MPU
p=argparse.ArgumentParser();p.add_argument('--main-rom',type=Path,required=True);p.add_argument('--cross',default='arm-none-eabi-');a=p.parse_args()
class Bus(list):
 def __init__(self):super().__init__([0xff]*65536);self[:0x800]=[0]*0x800;self.phase=0;self.head=[];self.motor=[]
 def __getitem__(self,n):
  if n==0x1000:self.phase^=0x40;return self.phase
  return super().__getitem__(n)
 def __setitem__(self,n,v):
  if n==0x1200:
   if v in (0x1a,0x1b):self.head.append(v&1)
   if v in (0x1c,0x1d):self.motor.append(v&1)
  super().__setitem__(n,v)
b=Bus();rom=a.main_rom.read_bytes();assert len(rom)==8192
b[0xe000:]=rom;b[0xa000:0xc000]=Path('test-cart.bin').read_bytes()
c=MPU(memory=b,pc=0xe041)
visited=False
for steps in range(200000):
 if c.pc==0xa006:visited=True
 if visited and c.pc==0xa014:break
 c.step()
else:raise AssertionError(f'Payload did not finish, PC={c.pc:04X}')
assert b[0x24:0x26]==[0x34,0x12]
assert not b.motor, 'No motor output expected'
head=[sum(bits[i]<<(7-i) for i in range(8)) for bits in [b.head[x:x+8] for x in range(0,len(b.head),8)]]
assert head[:2]==[0xe3,0xf3],head
assert head==[0xe3,0xf3,0x60,0xda,0xf2,0x66,0xe2],head
binary=Path('build/maxx-kff.bin').read_bytes();sp,reset=struct.unpack_from('<II',binary)
assert sp==0x10010000 and reset&1 and 0x08000000<reset<0x08100000
listing=subprocess.check_output([a.cross+'objdump','-d','build/maxx-kff.elf'],text=True)
serve=listing.split('<serve>:')[1]
assert '20000000 <serve>:' in listing
# Hot loop must not call a library routine or flash function.
assert not any('\tbl\t' in line or '\tbl.w\t' in line for line in serve.splitlines())
result={'reset_dispatch_and_display_payload':'passed','instructions_emulated':steps,'head_frame_hex':[f'{x:02X}' for x in head],'motor_bytes':len(b.motor),'ARM_vector_table':'passed','bus_loop_location':'SRAM 0x20000000','bus_loop_calls':0,'binary_sha256':hashlib.sha256(binary).hexdigest(),'main_rom_sha256':hashlib.sha256(rom).hexdigest(),'hardware_tested':False,'timing_verified':False}
Path('build/verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
