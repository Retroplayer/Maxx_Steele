"""Trace original LC8100 port writes, vocabulary tables, and phrase servicing."""

import argparse
import csv
import hashlib
import json
from pathlib import Path

from py65.devices.mpu6502 import MPU
from verify_remote import ROM_SHA256

WORDS = (
    "zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thir|fif|teen|twen|ty|hundred|a|"
    "accepted|again|ah|aid|aim|am|an|and|any|approach|are|awe|be|begin|boost|bout|but|by|can|charge|choice|choose|"
    "circuits|clear|congratulations|corded|day|dead|different|do|ear|easy|energy|enter|error|est|function|full|game|"
    "get|goes|good|great|hahahahaha|have|hello|how|human|I|if|I'm|in|indicate|ing|is|it|just|lay|let|liked|load|long|"
    "made|match|max|me|morn|my|name|need|no|now|ok|opponent|or|out|over|ow|pal|play|please|program|proper|re|ready|"
    "run|serve|some|sorry|sss|steele|suppose|sure|teach|test|thank|that|the|there|thing|time|tough|try|turn|up|upper|"
    "wait|was|way|were|what|when|who|whoops|will|win|would|yes|you|zz|[pause]"
).split("|")


class Bus(list):
    def __init__(self, rom):
        super().__init__(rom)
        self.writes = []
        self.status = 0x80
        self.cpu = None
        self.instruction_pc = 0

    def __getitem__(self, address):
        if address == 0x1200:
            return self.status
        return super().__getitem__(address)

    def __setitem__(self, address, value):
        if address in (0x1400, 0x1600, 0x1C00):
            self.writes.append({"pc": f"{self.instruction_pc:04X}", "port": f"{address:04X}",
                                "value": f"{value:02X}"})
        super().__setitem__(address, value)


class Trace:
    def __init__(self, rom):
        self.bus = Bus(rom)
        self.cpu = MPU(memory=self.bus)
        self.bus.cpu = self.cpu
        self.bus[0x92:0x94] = [0xD8, 0xF3]

    def run(self, entry, index=0, interrupt=False):
        self.cpu.pc = entry
        self.cpu.x = index
        self.cpu.p &= ~8  # Decimal mode is off in normal firmware.
        if interrupt:
            self.cpu.sp = 0xF9
            self.bus[0x1FA:0x200] = [0, 0, 0, self.cpu.p, 0xFF, 0x7F]
        else:
            self.cpu.sp = 0xFD
            self.bus[0x1FE:0x200] = [0xFE, 0x7F]
        begin = len(self.bus.writes)
        for _ in range(20000):
            if self.cpu.pc == 0x7FFF:
                return self.bus.writes[begin:]
            self.bus.instruction_pc = self.cpu.pc
            self.cpu.step()
        raise AssertionError(f"Routine did not return: {self.cpu.pc:04X}")


def word_trace(rom, code):
    trace = Trace(rom)
    writes = trace.run(0xF3D8, code)
    address = (rom[0xF567 + code] << 8) | rom[0xF4DB + code]
    nibbles = [0, address >> 12, (address >> 8) & 15, (address >> 4) & 15, address & 15]
    expected = []
    for nibble in nibbles[:4]:
        expected += [nibble, nibble | 0x10, nibble]
    expected += [nibbles[4], nibbles[4] | 0x80, nibbles[4]]
    assert [int(w["value"], 16) for w in writes] == expected
    assert all(w["port"] == "1400" for w in writes)
    assert trace.bus[0x57] == 0x80
    return {"code": code, "word": WORDS[code], "speech_address": f"{address:05X}",
            "address_band": "00000-00FFF" if address < 0x1000 else "04000-07FFF",
            "nibbles": " ".join(f"{n:X}" for n in nibbles), "writes": writes}


def analyze(rom):
    assert len(WORDS) == 141
    vocabulary = [word_trace(rom, code) for code in range(140)]
    assert all(int(v["speech_address"], 16) < 0x1000 or
               0x4000 <= int(v["speech_address"], 16) < 0x8000 for v in vocabulary)
    pause = Trace(rom)
    pause.bus[0x5B] = 0x80
    assert pause.run(0xF3D8, 140) == []
    assert pause.bus[0x5A] == 122 and pause.bus[0x5B] == 0xC0
    for _ in range(121):
        pause.run(0xF483, interrupt=True)
        assert pause.bus[0x5B] == 0xC0
    pause.run(0xF483, interrupt=True)
    assert pause.bus[0x5B] == 0x80

    phrases = []
    for index in range(16, 33):
        trace = Trace(rom)
        assert trace.run(0xF40F, index) == []
        start = trace.bus[0x58] | (trace.bus[0x59] << 8)
        assert trace.bus[0x5B] == 0x80
        tokens = []
        address = start
        while rom[address] != 0xFF:
            tokens.append(rom[address])
            address += 1
        assert all(token <= 140 for token in tokens)
        phrases.append({"phrase": index, "cpu_address": f"{start:04X}",
                        "tokens": tokens, "text_fragments": [WORDS[t] for t in tokens]})
    assert phrases[0]["cpu_address"] == "F5F3" and address == 0xF64D

    # Check all RAM phrase pointers and the asynchronous ready/busy sequencing.
    for index in range(16):
        trace = Trace(rom)
        trace.run(0xF40F, index)
        assert trace.bus[0x58] | (trace.bus[0x59] << 8) == 0x500 + 16 * index
    trace = Trace(rom)
    trace.run(0xF40F, 16)
    first = trace.run(0xF483, interrupt=True)
    assert first == vocabulary[65]["writes"]  # phrase 16 starts with hello.
    assert trace.bus[0x57] == 0x80 and trace.bus[0x58] == 0xF4
    assert trace.run(0xF483, interrupt=True) == []  # Not-ready-observed latch.
    trace.bus.status = 0
    trace.run(0xF483, interrupt=True)
    assert trace.bus[0x57] == 0
    trace.bus.status = 0x80
    assert trace.run(0xF483, interrupt=True) == []  # Next token is software pause.
    assert trace.bus[0x5A] == 122 and trace.bus[0x5B] == 0xC0

    return {"rom_sha256": ROM_SHA256,
            "scope": "Original CPU instruction traces with modeled port status; speech chips not emulated",
            "summary": {"word_entries_verified": 140, "writes_per_word": 15,
                        "address_strobe_pulses_per_word": 4, "start_pulses_per_word": 1,
                        "low_band_entries": sum(v["address_band"] == "00000-00FFF" for v in vocabulary),
                        "high_band_entries": sum(v["address_band"] == "04000-07FFF" for v in vocabulary),
                        "rom_phrases_verified": 17, "ram_phrase_pointers_verified": 16,
                        "pause_service_calls": 122, "ready_busy_latch_verified": True},
            "vocabulary": vocabulary, "phrases": phrases}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--words", type=Path, required=True)
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    if len(rom) != 65536 or hashlib.sha256(rom).hexdigest() != ROM_SHA256:
        parser.error("Expected the verified mapped ROM")
    result = analyze(rom)
    args.report.write_text(json.dumps(result, indent=2) + "\n")
    with args.words.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["code", "word", "speech_address", "address_band", "nibbles"])
        writer.writeheader()
        writer.writerows({k: v[k] for k in writer.fieldnames} for v in result["vocabulary"])
    print(json.dumps(result["summary"], indent=2))


if __name__ == "__main__":
    main()
