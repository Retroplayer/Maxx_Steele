"""Trace all three direct $1600 writers and proposed no-write patch effects.

Only temporary emulator copies are patched; the supplied ROM is never changed.
"""

import argparse
import hashlib
import json
from pathlib import Path

from analyze_speech import Trace
from verify_remote import ROM_SHA256

WRITERS = (0xF21D, 0xF4BF, 0xF4D3)


def port_writes(writes, port):
    return [w for w in writes if w["port"] == port]


def feedback(value):
    return ((value << 1) & 255) | (1 ^ ((value >> 5) & 1) ^ ((value >> 6) & 1))


def analyze(rom):
    for address in WRITERS:
        assert rom[address:address + 3] == bytes.fromhex("8d 00 16")
    patched = bytearray(rom)
    for address in WRITERS:
        patched[address:address + 3] = b"\xea\xea\xea"

    seeds = []
    for seed in range(256):
        original, modified = Trace(rom), Trace(patched)
        for trace in (original, modified):
            trace.bus.status = 0  # Speech busy.
            trace.bus[0x5C] = seed
            trace.bus[0x5D] = 1
            trace.bus[0x57] = 0x80
        writes = original.run(0xF483, interrupt=True)
        other = modified.run(0xF483, interrupt=True)
        assert [int(w["value"], 16) for w in port_writes(writes, "1600")] == [seed]
        assert not port_writes(other, "1600")
        for trace in (original, modified):
            assert trace.bus[0x5C] == feedback(seed)
            assert trace.bus[0x5D] == 16 and trace.bus[0x57] == 0
        assert original.bus[:0x1000] == modified.bus[:0x1000]
        assert original.cpu.p == modified.cpu.p
        if seed < 8:
            seeds.append({"seed": seed, "next": feedback(seed), "writes": writes})

    trace = Trace(rom)
    trace.bus.status = 0
    trace.bus[0x5D] = 1
    trace.run(0xF483, interrupt=True)
    for _ in range(15):
        assert not port_writes(trace.run(0xF483, interrupt=True), "1600")
    assert len(port_writes(trace.run(0xF483, interrupt=True), "1600")) == 1
    initial = Trace(rom)
    initial.bus.status = 0
    for _ in range(255):
        assert not port_writes(initial.run(0xF483, interrupt=True), "1600")
    assert len(port_writes(initial.run(0xF483, interrupt=True), "1600")) == 1

    music_examples = []
    for voice in range(3):
        for note in range(25):
            original, modified = Trace(rom), Trace(patched)
            original.cpu.a = modified.cpu.a = note
            writes = original.run(0xF21C, voice)
            other = modified.run(0xF21C, voice)
            assert [int(w["value"], 16) for w in port_writes(writes, "1600")] == [note]
            assert not port_writes(other, "1600")
            assert len(port_writes(writes, "1C00")) == (1 if note == 0 else 4)
            assert port_writes(writes, "1C00") == port_writes(other, "1C00")
            assert original.bus[:0x1000] == modified.bus[:0x1000]
            assert (original.cpu.a, original.cpu.x, original.cpu.y, original.cpu.p) == (
                modified.cpu.a, modified.cpu.x, modified.cpu.y, modified.cpu.p)
            if voice == 0 and note in (0, 1, 12, 24):
                music_examples.append({"note": note, "writes": writes})

    for kind in ("phrase_end", "direct_sound_end"):
        original, modified = Trace(rom), Trace(patched)
        for trace in (original, modified):
            trace.bus[0x5B] = 0x80 if kind == "phrase_end" else 0x20
            trace.bus[0x58:0x5A] = [0, 5]
            trace.bus[0x500] = 0xFF
        writes = original.run(0xF483, interrupt=True)
        other = modified.run(0xF483, interrupt=True)
        assert [w["value"] for w in port_writes(writes, "1600")] == ["00"]
        assert not port_writes(other, "1600")
        assert original.bus[0x5B] == modified.bus[0x5B] == 0
        assert original.bus[:0x1000] == modified.bus[:0x1000]
        assert original.cpu.p == modified.cpu.p

    sequence, value = [], 0
    for _ in range(24):
        sequence.append(f"{value:02X}")
        value = feedback(value)
    return {"rom_sha256": ROM_SHA256,
            "scope": "Original instruction traces and emulator-only no-write variants; no hardware or ROM image patched",
            "writers": [{"cpu_address": f"{a:04X}", "raw_8k_offset": f"{a - 0xE000:04X}",
                         "original": "8D 00 16", "no_write_candidate": "EA EA EA"} for a in WRITERS],
            "summary": {"speech_seed_cases": 256, "music_cases": 75,
                        "completion_cases": 2, "speech_update_divider": 16,
                        "initial_zero_divider_first_update_calls": 256,
                        "music_output_preserved_in_no_write_model": True,
                        "speech_ram_and_flags_preserved_in_no_write_model": True},
            "initial_sequence": sequence, "seed_examples": seeds,
            "music_examples": music_examples}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    if len(rom) != 65536 or hashlib.sha256(rom).hexdigest() != ROM_SHA256:
        parser.error("Expected the verified mapped ROM")
    result = analyze(rom)
    args.report.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result["summary"], indent=2))


if __name__ == "__main__":
    main()
