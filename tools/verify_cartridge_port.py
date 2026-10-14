"""Verify CPU-side cartridge discovery and default NMI dispatch in original ROM."""
import argparse
import hashlib
import json
from pathlib import Path
from py65.devices.mpu6502 import MPU
from verify_remote import ROM_SHA256


def verify(rom, cart):
    assert hashlib.sha256(rom).hexdigest() == ROM_SHA256
    assert rom[0xFFFA:0xFFFC] == bytes([0x11, 0xE0])
    assert rom[0xE011:0xE014] == bytes([0x6C, 0x76, 0])
    assert rom[0xE020:0xE022] == bytes([0x14, 0xE0])
    mem = list(rom)
    mem[0x76:0x78] = [0x14, 0xE0]
    mem[0x1E00] = 255
    m = MPU(memory=mem)
    m.pc, m.a, m.x, m.y, m.sp = 0x7FFF, 0x5A, 0x31, 0x62, 0xFF
    m.nmi()
    pcs = []
    for _ in range(20):
        if m.pc == 0x7FFF:
            break
        pcs.append(f'{m.pc:04X}')
        m.step()
    assert m.pc == 0x7FFF and (m.a, m.x, m.y) == (0x5A, 0x31, 0x62)
    assert m.sp == 0xFF and mem[0x1E00] == 0
    assert hashlib.sha256(cart).hexdigest() == 'db78d27d6660bfc08a9970ba0c72f7ce67216388c683d77820aa87740fc10be9'
    entry = int.from_bytes(cart[:2], 'little')
    mem = list(rom)
    mem[0xA000:0xA000+len(cart)] = cart
    mem[0x8E:0x90] = [0, 0x10]
    m = MPU(memory=mem)
    m.pc = 0xE090
    for _ in range(1000):
        if m.pc == entry:
            break
        m.step()
    assert m.pc == entry == 0xA013
    return {'rom_sha256': ROM_SHA256,
            'NMI': {'hardware_vector': 'E011', 'RAM_vector': '0076',
                    'default_handler': 'E014', 'executed_pcs': pcs,
                    'write_1E00': '00', 'registers_and_stack_restored': True},
            'demo_cartridge': {'header': cart[:6].hex(' ').upper(),
                               'mapped_base': 'A000', 'dispatch_entry': f'{entry:04X}',
                               'original_probe_executed': True},
            'limits': 'Firmware only; connector labels, ASIC decoding, and electrical timing are not emulated.'}


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('rom', type=Path)
    p.add_argument('cartridge', type=Path)
    p.add_argument('--output', type=Path)
    args = p.parse_args()
    output = json.dumps(verify(args.rom.read_bytes(), args.cartridge.read_bytes()), indent=2) + '\n'
    if args.output:
        args.output.write_text(output)
    else:
        print(output)
