"""Replay synthetic receiver levels through the original ROM using py65.

This verifies ROM behavior, not the RF/jack electrical interface or real timing.
Install py65==1.2.0 in a virtual environment, then supply the mapped ROM path.
"""

import argparse
import csv
import hashlib
import json
from pathlib import Path

from py65.devices.mpu6502 import MPU


ROM_SHA256 = "d6359ba53a5072ecf2e8703cecda8c63bb9a47c8f39cd07dd047089b2f2c1746"
KEYS = [
    "0 / Drive left", "1 / Drive forward", "2 / Drive reverse",
    "3 / Drive right", "4 / Wrist up", "5 / Wrist down",
    "6 / Arms up", "7 / Arms down", "8 / Claw rotate",
    "9 / Claw open-close", "Lamp", "Home", "Wait / Note rest",
    "Shift octave", "Clear", "Enter", "Song / Notes", "Clock / Status",
    "Speech", "Motion / Back step", "Game", "Program", "Learn",
    "Execute", "Power / Stop",
]


def encode(key_id, release=False):
    data = key_id | (0x20 if release else 0)
    return data | ((data.bit_count() & 3) << 6)


def symbols(byte):
    bits = f"{byte:08b}"
    return "1" + bits[:3] + str(1 - int(bits[2])) + bits[3:6] + str(1 - int(bits[5])) + bits[6:]


class Receiver:
    def __init__(self, rom, trace=False):
        self.cpu = MPU()
        self.cpu.memory[:] = rom
        self.mem = self.cpu.memory
        # Reproduce relevant reset state; other RAM and queue indices are zero.
        self.mem[0x67] = self.mem[0x6A] = 0xFF
        self.mem[0x75] = 0x80
        self.mem[0x7A:0x7C] = [0xCB, 0xE0]
        self.stopped = False
        self.ticks = 0
        self.trace = [] if trace else None

    def tick(self, level):
        m = self.cpu
        self.ticks += 1
        self.mem[0x1400] = level << 7
        m.pc = 0xFC6F
        # A synthetic JSR return address, outside firmware and peripherals.
        m.sp = 0xFD
        self.mem[0x1FE:0x200] = [0xFE, 0x7F]
        for _ in range(1000):
            if m.pc == 0x7FFF:
                return
            if m.pc == 0xE0CB:
                self.stopped = True
                return  # Record the nonlocal Power/Stop jump, not full startup.
            if self.trace is not None:
                self.trace.append([
                    self.ticks, level, f"{m.pc:04X}", f"{self.mem[m.pc]:02X}",
                    f"{m.a:02X}", f"{m.x:02X}", f"{m.y:02X}", f"{m.p:02X}",
                    self.mem[0x62], self.mem[0x63], f"{self.mem[0x64]:02X}",
                    f"{self.mem[0x75]:02X}", self.mem[0xA1], self.mem[0xA2],
                ])
            m.step()
        raise AssertionError(f"Receiver did not return; PC={m.pc:04X}")

    def send(self, byte, bad_guard=False):
        frame = list(symbols(byte))
        if bad_guard:
            frame[4] = frame[3]
        # Chosen synthetic timing: 3 receiver calls per symbol, 6 low idle calls.
        for bit in frame:
            for _ in range(3):
                self.tick(int(bit))
                if self.stopped:
                    return
        for _ in range(6):
            self.tick(0)

    def take(self):
        value = self.mem[0x75]
        self.mem[0x75] = 0x80
        return value


def verify(rom):
    results = []
    for key_id, name in enumerate(KEYS, 1):
        r = Receiver(rom)
        r.send(encode(key_id))
        assert r.mem[0xA1] == r.mem[0xA2] == 0
        if key_id == 25:
            assert r.stopped and r.take() == 0x80
        else:
            assert not r.stopped and r.take() == key_id - 1
            r.send(encode(key_id))
            assert r.take() == 0x80, "Held repeats must not enqueue new presses"
            r.send(encode(key_id, True))
            assert r.take() == key_id - 1 + 0x20
            assert r.mem[0x66] == 0 and r.mem[0x67] == 0xFF
        results.append({
            "key": name, "key_id": key_id,
            "press_byte": f"{encode(key_id):02X}",
            "release_byte": f"{encode(key_id, True):02X}",
            "press_symbols": symbols(encode(key_id)),
            "event": "nonlocal stop jump" if key_id == 25 else f"{key_id - 1:02X}",
        })

    # Every 8-bit value: only the 64 valid population-count checksums pass.
    valid = invalid = 0
    for byte in range(256):
        r = Receiver(rom)
        r.send(byte)
        good = (byte >> 6) == ((byte & 0x3F).bit_count() & 3)
        assert r.mem[0xA1] == (0 if good else 1), f"checksum {byte:02X}"
        valid += good
        invalid += not good

    r = Receiver(rom)
    r.send(encode(1), bad_guard=True)
    assert r.mem[0xA1] > 0 and r.take() == 0x80

    r = Receiver(rom)
    r.send(encode(1))
    assert r.take() == 0
    remaining = 200 - r.mem[0x67]
    for _ in range(remaining - 1):
        r.tick(0)
        assert r.mem[0x75] == 0x80
    r.tick(0)
    assert r.take() == 0x20 and r.mem[0x67] == 0xFF

    r = Receiver(rom)
    r.send(encode(1))
    assert r.take() == 0
    r.send(encode(2))
    assert r.take() == 1 and r.mem[0x66] == 1 and r.mem[0x69] == 2
    r.send(encode(3))
    assert r.stopped and r.mem[0xA2] == 1

    return {
        "rom_sha256": ROM_SHA256,
        "scope": "Synthetic input replay of original FC6F decoder; no physical timing validation",
        "checks": {
            "key_presses": 25, "held_repeats": 24, "matched_releases": 24,
            "checksum_values": 256, "valid_checksums": valid,
            "invalid_checksums": invalid, "bad_guard_rejected": True,
            "timeout_at_200_calls": True, "two_active_keys": True,
            "third_active_key_stop": True,
        },
        "keys": results,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--trace", type=Path, help="Instruction CSV for the first key's press")
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    if len(rom) != 65536 or hashlib.sha256(rom).hexdigest() != ROM_SHA256:
        parser.error("Expected the verified 64 KiB Maxx_Steele_Main_Mapped.bin")
    report = verify(rom)
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    if args.trace:
        r = Receiver(rom, trace=True)
        r.send(encode(1))
        assert r.take() == 0
        with args.trace.open("w", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow([
                "tick", "radio_level", "pc", "opcode", "a", "x", "y", "p",
                "counter_62", "state_63", "shift_64", "mailbox_75", "errors_a1", "errors_a2",
            ])
            writer.writerows(r.trace)
    print(json.dumps(report["checks"], indent=2))


if __name__ == "__main__":
    main()
