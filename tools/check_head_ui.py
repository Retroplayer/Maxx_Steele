#!/usr/bin/env python3
"""Test head UI labels against frames executed from the original 6502 ROM."""
import argparse
import subprocess
import tempfile
from pathlib import Path
from analyze_head_display import Trace, byte_values
from verify_remote import ROM_SHA256
import hashlib

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, required=True)
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    assert len(rom) == 65536 and hashlib.sha256(rom).hexdigest() == ROM_SHA256
    labels = {0:"Turn left",1:"Forward",2:"Backward",3:"Turn right",4:"Wrist up",
              5:"Wrist down",6:"Arms up",7:"Arms down",8:"Rotate claw",9:"Claw",
              10:"Headlamp",12:"Wait",0x81:"Song",0x82:"Speech code",
              0x83:"Sentence",0x84:"Edit sentence"}
    fixtures = []
    for command, label in labels.items():
        index = (command & 7) + 12 if command & 128 else command
        limit = rom[0xe5ec + index]
        for entry, operands in [(0xf668, [0]), (0xf66c, range(limit+1))]:
            for operand in operands:
                trace = Trace(rom)
                trace.bus[0x11] = command; trace.bus[0x13] = operand
                result = byte_values(trace.run(entry))
                assert result[:2] == [0xe3,0xf3] and result[-1] == 0xe2
                fixtures.append(" ".join(f"{b:02x}" for b in result[2:6]) + " " + label)
    with tempfile.TemporaryDirectory() as folder:
        exe = str(Path(folder)/"head-ui-test")
        subprocess.run(["g++","-std=c++11","-Wall","-Wextra","-Werror","-pedantic",
                        str(ROOT/"head/tests/ui_test.cpp"),"-o",exe],check=True)
        subprocess.run([exe],check=True)
        subprocess.run([exe,"--fixtures"], input="\n".join(fixtures)+"\n",text=True,check=True)
    print(f"PASS: {len(fixtures)} original-ROM prompt/value frames, all legal operands for 16 command types")


if __name__ == "__main__":
    main()
