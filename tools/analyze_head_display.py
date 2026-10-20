"""Trace original head-display routines and their actual serial port writes."""

import argparse
import hashlib
import json
from pathlib import Path

from py65.devices.mpu6502 import MPU
from verify_remote import ROM_SHA256

SEGMENTS = ((7, "a"), (6, "b"), (5, "c"), (4, "d"),
            (3, "e"), (2, "f"), (1, "g"), (0, "dp"))
DIGIT_MASKS = [0xFC, 0x60, 0xDA, 0xF2, 0x66, 0xB6, 0xBE, 0xE0,
               0xFE, 0xE6, 0xEE, 0x3E, 0x9C, 0x7A, 0x9E, 0x8E]


class Bus(list):
    def __init__(self, rom):
        super().__init__(rom)
        self.clock = 0
        self.pc = 0
        self.writes = []

    def __getitem__(self, address):
        if address == 0x1000:
            # A modeled high/low timing reference for the two polling waits.
            # This is not a measurement of the ASIC or COP clock.
            self.clock ^= 0x40
            return self.clock
        return super().__getitem__(address)

    def __setitem__(self, address, value):
        if address == 0x1200:
            self.writes.append({"pc": f"{self.pc:04X}", "value": f"{value:02X}"})
        super().__setitem__(address, value)


class Trace:
    def __init__(self, rom):
        self.bus = Bus(rom)
        self.cpu = MPU(memory=self.bus)

    def run(self, entry, a=0, x=0):
        self.cpu.pc, self.cpu.a, self.cpu.x = entry, a, x
        self.cpu.sp = 0xFD
        self.cpu.p &= ~8
        self.bus[0x1FE:0x200] = [0xFE, 0x7F]
        self.bus.writes = []
        serial = []
        for _ in range(30000):
            if self.cpu.pc == 0x7FFF:
                break
            if self.cpu.pc in (0xED4F, 0xED55):
                serial.append({"sender": f"{self.cpu.pc:04X}", "byte": f"{self.cpu.a:02X}"})
            self.bus.pc = self.cpu.pc
            self.cpu.step()
        else:
            raise AssertionError(f"Routine did not return: {self.cpu.pc:04X}")
        # Independently recover bytes from the actual data-phase STA operations.
        data = [int(w["value"], 16) for w in self.bus.writes if w["pc"] == "ED69"]
        assert len(data) == len(serial) * 8
        for index, packet in enumerate(serial):
            phase = data[8 * index:8 * index + 8]
            base = 0x1A if packet["sender"] == "ED4F" else 0x1C
            assert all(value in (base, base | 1) for value in phase)
            byte = 0
            for value in phase:
                byte = (byte << 1) | (value & 1)
            assert byte == int(packet["byte"], 16)
        assert all(w["value"] == "F8" for w in self.bus.writes if w["pc"] == "ED73")
        return {"serial": serial, "port_writes": self.bus.writes}


def byte_values(trace):
    return [int(packet["byte"], 16) for packet in trace["serial"]]


def analyze(rom):
    assert list(rom[0xF8BE:0xF8CE]) == DIGIT_MASKS
    glyphs = [{"label": f"{n:X}", "mask": f"{mask:02X}",
               "segments": [label for bit, label in SEGMENTS if mask & (1 << bit)]}
              for n, mask in enumerate(DIGIT_MASKS)]
    presets = []
    for index in range(32):
        result = Trace(rom).run(0xF684, x=index)
        expected = [rom[base + index] for base in (0xF858, 0xF838, 0xF818, 0xF7F8)]
        assert byte_values(result) == [0xE3, 0xF3] + expected + [0xE2]
        presets.append({"index": index, "glyphs": [f"{v:02X}" for v in expected],
                        "segments": [[label for bit, label in SEGMENTS if v & (1 << bit)]
                                     for v in expected]})

    numeric_examples = []
    for number in range(256):
        trace = Trace(rom)
        trace.bus[0x13] = number
        trace.run(0xF737)
        packed = trace.bus[0x25] << 8 | trace.bus[0x24]
        assert packed == int(f"{number:04d}", 16)
        result = trace.run(0xF6D6)
        expected = [DIGIT_MASKS[int(d)] for d in f"{number:04d}"]
        assert byte_values(result) == [0xE3, 0xF3] + expected + [0xE2]
        # Same formatted value with leading-zero suppression (X=$FF).
        result_blank = trace.run(0xF6D8, x=0xFF)
        text = f"{number:04d}".lstrip("0") or "0"
        masks = [0] * (4 - len(text)) + [DIGIT_MASKS[int(d)] for d in text]
        assert byte_values(result_blank) == [0xE3, 0xF3] + masks + [0xE2]
        if number in (0, 1, 12, 123, 255):
            numeric_examples.append({"number": number,
                                     "zero_filled": result["serial"],
                                     "leading_blanks": result_blank["serial"]})

    # Validate shared-data / separate-clock-control behavior for every byte.
    for value in range(256):
        assert byte_values(Trace(rom).run(0xED4F, a=value)) == [value]
        assert byte_values(Trace(rom).run(0xED55, a=value)) == [value]

    example = Trace(rom).run(0xF684, x=7)
    mixed_examples = []
    for command in list(range(16)) + list(range(0x80, 0x85)) + [0xFE, 0xFF]:
        for operand in (0, 1, 99, 140, 255):
            trace = Trace(rom)
            trace.bus[0x11] = command
            trace.bus[0x13] = operand
            result = trace.run(0xF66C)
            values = byte_values(result)
            assert len(values) == 7 and values[:2] == [0xE3, 0xF3] and values[-1] == 0xE2
            if command == 0xFE:
                assert values[2:6] == [0, 0x3E, 0x9E, 0xF6]
            elif command == 0xFF:
                assert values[2:6] == [0, 0x9E, 0x2A, 0x7A]
            elif command == 0x0B:
                assert values[2:6] == [0x20, 0x2A, 0x20, 0x1E]
            mixed_examples.append({"command": f"{command:02X}", "operand": operand,
                                   "serial": result["serial"]})
    music_examples = []
    for octave in (0, 1):
        trace = Trace(rom)
        trace.bus[0x39] = octave
        trace.bus[0x400:0x402] = [0x70, 0x12]
        result = trace.run(0xF0D0)
        assert byte_values(result) == [0xE3, 0xF3, 0xFC | octave, 0xFC, 0x8E, 0xF2, 0xE2]
        music_examples.append({"octave_flag": octave, "serial": result["serial"]})
    clock_adjust_examples = []
    for selection, adjustment, name in ((0xE0, 0xE8, "clock hours"),
                                         (0xE0, 0xE7, "clock minutes"),
                                         (0xE1, 0xEA, "alarm hours"),
                                         (0xE1, 0xE9, "alarm minutes")):
        trace = Trace(rom)
        trace.bus[0x75] = 0  # Pending key ends the adjustment-repeat wait.
        result = trace.run(0xF7D9, a=selection, x=adjustment)
        assert byte_values(result) == [selection, adjustment]
        clock_adjust_examples.append({"function": name, "serial": result["serial"]})
    return {"rom_sha256": ROM_SHA256,
            "scope": "Original CPU routines with modeled timing-reference reads; head COP not emulated",
            "summary": {"segment_masks": 16, "preset_messages": 32,
                        "bcd_values_checked": 256, "numeric_formatters_checked": 2,
                        "head_sender_values_checked": 256, "motor_sender_values_checked": 256,
                        "mixed_format_cases_checked": len(mixed_examples),
                        "decimal_point_cases_checked": 2,
                        "clock_alarm_adjust_pairs_checked": 4,
                        "prefix": ["E3", "F3"], "suffix": ["E2"],
                        "data_bytes_per_update": 4, "bit_order": "MSB first"},
            "segment_mapping": {str(bit): label for bit, label in SEGMENTS},
            "glyphs": glyphs, "presets": presets, "numeric_examples": numeric_examples,
            "program_prompt_trace": example, "decimal_point_examples": music_examples,
            "mixed_format_examples": mixed_examples,
            "clock_alarm_adjust_examples": clock_adjust_examples}


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
