"""Decode the supplied sigrok archive and replay its real D0 samples through ROM.

Requires py65==1.2.0 and verify_remote.py in the same tools directory.
No files from the archive are extracted or executed.
"""

import argparse
import configparser
import csv
import hashlib
import io
import json
import statistics
from collections import Counter
from pathlib import Path
from zipfile import ZipFile

from verify_remote import Receiver, ROM_SHA256


EXPECTED_IDS = {
    **{str(n): n + 1 for n in range(10)},
    "B": 12, "CLEAR": 15, "CLOCK": 18, "ENTER": 16, "EXECUTE": 24,
    "GAME": 21, "LEARN": 23, "MOTION": 20, "OCTAVE": 14,
    "PROGRAM": 22, "SONG": 17, "SPEECH": 19, "WAIT": 13,
}
DATA_POSITIONS = (1, 2, 3, 5, 6, 7, 9, 10)


def runs(samples):
    start = 0
    level = samples[0] & 1
    result = []
    for i, value in enumerate(samples[1:], 1):
        new = value & 1
        if new != level:
            result.append((start, level, i - start))
            start, level = i, new
    result.append((start, level, len(samples) - start))
    return result


def decode_edges(samples):
    frames = []
    bits = ""
    start = 0
    unit_estimates = []
    partial_tail = None
    for sample, level, duration in runs(samples):
        if level == 0 and duration > 8000:
            if bits:
                # Final zero data symbols merge into the long low idle run.
                assert len(bits) <= 11, "Overlength frame before idle"
                frame = bits.ljust(11, "0")
                assert frame[0] == "1"
                assert frame[4] != frame[3] and frame[8] != frame[7]
                code = int("".join(frame[i] for i in DATA_POSITIONS), 2)
                assert code >> 6 == ((code & 0x3F).bit_count() & 3)
                frames.append({
                    "start_us": start, "symbols": frame, "code": f"{code:02X}",
                    "key_id": code & 0x1F, "release": bool(code & 0x20),
                })
                bits = ""
        else:
            count = round(duration / 1580)
            if count == 0 and sample + duration == len(samples):
                partial_tail = {"start_us": sample, "observed_us": duration,
                                "reason": "Capture ends during a sub-symbol pulse"}
                break
            if not bits:
                assert level == 1, "Frame must begin high"
                start = sample
            assert count >= 1
            bits += str(level) * count
            unit_estimates.append(duration / count)
    if bits:
        partial_tail = {"start_us": start, "partial_symbols": bits,
                        "reason": "Capture ends before a complete frame and idle"}
    return frames, unit_estimates, partial_tail


def analyze(archive, rom, tick_us):
    captures = []
    all_frames = []
    symbol_estimates = []
    repeat_intervals = []
    with ZipFile(archive) as outer:
        names = [n for n in outer.namelist() if n.endswith(".sr")]
        assert {Path(n).stem for n in names} == set(EXPECTED_IDS)
        pinout = outer.read("pinout.txt").decode().strip()
        for name in names:
            with ZipFile(io.BytesIO(outer.read(name))) as inner:
                meta = configparser.ConfigParser()
                meta.read_string(inner.read("metadata").decode())
                device = meta["device 1"]
                assert device["samplerate"] == "1 MHz" and device["unitsize"] == "1"
                assert inner.getinfo("logic-1-1").file_size == 500000
                samples = inner.read("logic-1-1")
            frames, units, partial_tail = decode_edges(samples)
            symbol_estimates.extend(units)
            key_id = EXPECTED_IDS[Path(name).stem]
            assert frames and all(f["key_id"] == key_id for f in frames)
            assert any(not f["release"] for f in frames)
            assert any(f["release"] for f in frames)
            for a, b in zip(frames, frames[1:]):
                if a["code"] == b["code"] and not a["release"]:
                    repeat_intervals.append(b["start_us"] - a["start_us"])

            receiver = Receiver(rom)
            events, replay_codes = [], []
            for sample in range(0, len(samples), tick_us):
                previous_state = receiver.mem[0x63]
                receiver.tick(samples[sample] & 1)
                assert not receiver.stopped
                if previous_state == 10 and receiver.mem[0x63] == 0:
                    replay_codes.append(f"{receiver.mem[0x64]:02X}")
                if receiver.mem[0x75] < 0x80:
                    events.append({"time_us": sample, "event": f"{receiver.take():02X}"})
            assert receiver.mem[0xA1] == receiver.mem[0xA2] == 0
            assert replay_codes == [f["code"] for f in frames]
            assert all(int(e["event"], 16) in (key_id - 1, key_id - 1 + 0x20) for e in events)
            assert events and any(int(e["event"], 16) == key_id - 1 for e in events)
            assert any(int(e["event"], 16) == key_id - 1 + 0x20 for e in events)
            counts = Counter(f["code"] for f in frames)
            captures.append({
                "file": name, "sample_rate_hz": 1000000, "samples": len(samples),
                "key_id": key_id, "frames": len(frames), "code_counts": dict(counts),
                "events": events, "framing_checksum_errors": 0, "active_slot_errors": 0,
                "incomplete_tail": partial_tail,
            })
            all_frames.extend({"capture": name, **frame} for frame in frames)

    return {
        "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        "rom_sha256": ROM_SHA256,
        "scope": "Real receiver-output samples; original ROM decoder replay; transmitter jack unmeasured",
        "replay_tick_us": tick_us,
        "replay_tick_note": "Chosen accepted replay interval, not a measured hardware IRQ period",
        "captures": captures,
        "summary": {
            "capture_files": len(captures), "decoded_frames": len(all_frames),
            "rom_frames_matching_edge_decode": len(all_frames),
            "framing_checksum_errors": 0, "active_slot_errors": 0,
            "symbol_period_us_median": statistics.median(symbol_estimates),
            "normalized_symbol_period_us_min": min(symbol_estimates),
            "normalized_symbol_period_us_max": max(symbol_estimates),
            "held_repeat_interval_us_median": statistics.median(repeat_intervals),
            "held_repeat_interval_us_min": min(repeat_intervals),
            "held_repeat_interval_us_max": max(repeat_intervals),
            "missing_keys": ["Lamp", "Power / Stop"],
            "captures_with_incomplete_tail": [c["file"] for c in captures if c["incomplete_tail"]],
        },
        "receiver_wiring_note_verbatim": pinout,
    }, all_frames


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--tick-us", type=int, default=528)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--frames", type=Path, required=True)
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    if len(rom) != 65536 or hashlib.sha256(rom).hexdigest() != ROM_SHA256:
        parser.error("Expected the verified mapped ROM")
    if args.tick_us <= 0:
        parser.error("--tick-us must be positive")
    report, frames = analyze(args.archive, rom, args.tick_us)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    with args.frames.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(frames[0]))
        writer.writeheader()
        writer.writerows(frames)
    print(json.dumps(report["summary"], indent=2))


if __name__ == "__main__":
    main()
