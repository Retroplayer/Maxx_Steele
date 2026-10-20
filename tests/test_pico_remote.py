"""Host checks of actual PIO source, scheduling, and original ROM acceptance."""

import ast
import bisect
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "pico"), str(ROOT / "tools"), str(ROOT / "pc")]
from controller import Controller
from protocol import encode, key_id, pio_word, SYMBOL_US, FRAME_PERIOD_US
from verify_remote import Receiver, ROM_SHA256
import hashlib
from remote_cli import Remote


def simulate_pio(words, inverted=False):
    """Execute PIO instructions parsed from main.py, counting hardware cycles."""
    tree = ast.parse((ROOT / "pico" / "main.py").read_text())
    factory = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "make_program")
    body = next(n for n in factory.body if isinstance(n, ast.FunctionDef)).body
    instructions, labels = [], {}

    def arg(node):
        return node.id if isinstance(node, ast.Name) else ast.literal_eval(node)

    for statement in body:
        call = statement.value
        op = call.func.id
        values = [arg(a) for a in call.args]
        if op == "label":
            labels[values[0]] = len(instructions)
        elif op not in ("wrap", "wrap_target"):
            instructions.append((op, values))

    fifo = list(words)
    registers = {"x": 0, "y": 0, "isr": SYMBOL_US - 4, "osr": 0}
    pc = cycles = 0
    output = [(0, int(inverted))]
    writes = []
    while cycles < 200000:
        op, args = instructions[pc]
        next_pc = (pc + 1) % len(instructions)
        if op == "pull":
            if not fifo:
                break
            registers["osr"] = fifo.pop(0)
        elif op == "set":
            registers[args[0]] = args[1]
        elif op == "mov":
            registers[args[0]] = registers[args[1]]
        elif op == "out":
            destination, count = args
            value = registers["osr"] >> (32 - count)
            registers["osr"] = (registers["osr"] << count) & 0xFFFFFFFF
            if destination == "pins":
                writes.append((cycles, value))
                output.append((cycles, value))
            else:
                registers[destination] = value
        elif op == "jmp":
            register = args[0][0]
            old = registers[register]
            registers[register] = (old - 1) & 0xFFFFFFFF
            if old:
                next_pc = labels[args[1]]
        else:
            raise AssertionError("Unsupported PIO instruction " + op)
        pc = next_pc
        cycles += 1
    else:
        raise AssertionError("PIO program never stalled on an empty FIFO")
    return output, writes, cycles


class ProtocolTests(unittest.TestCase):
    def test_capture_codes_and_pio_timing(self):
        known = [0x41, 0x42, 0x83, 0x44, 0x85, 0x86, 0xC7, 0x48,
                 0x89, 0x8A, 0xCB, 0x8C, 0xCD, 0xCE, 0x0F, 0x50,
                 0x91, 0x92, 0xD3, 0x94, 0xD5, 0xD6, 0x17, 0x98, 0xD9]
        self.assertEqual([encode(k) for k in range(1, 26)], known)
        self.assertEqual(key_id("FORWARD"), 2)
        self.assertEqual(key_id("1"), 2)
        for inverted in (False, True):
            for key in range(1, 26):
                _, writes, _ = simulate_pio([
                    pio_word(key, inverted=inverted),
                    pio_word(key, True, inverted=inverted)], inverted)
                self.assertEqual(len(writes), 24)
                for offset in (0, 12):
                    self.assertEqual([writes[i + 1][0] - writes[i][0]
                                      for i in range(offset, offset + 11)], [SYMBOL_US] * 11)
                    self.assertEqual(writes[offset + 11][1], int(inverted))
                self.assertEqual(writes[12][0] - writes[0][0], FRAME_PERIOD_US)

    def test_generated_pio_waveforms_in_original_rom(self):
        filename = os.environ.get("MAXX_ROM")
        if not filename:
            self.fail("Set MAXX_ROM to the mapped ROM; ROM checks must execute")
        rom = Path(filename).read_bytes()
        self.assertEqual(hashlib.sha256(rom).hexdigest(), ROM_SHA256)
        for key in range(1, 26):
            receiver = Receiver(rom)
            edges, _, elapsed = simulate_pio([pio_word(key), pio_word(key, True)])
            times = [t for t, _ in edges]
            events = []
            for t in range(0, elapsed + 6000, 528):
                level = edges[bisect.bisect_right(times, t) - 1][1]
                receiver.tick(level)
                if receiver.stopped:
                    break
                if receiver.mem[0x75] < 0x80:
                    events.append(receiver.take())
            self.assertEqual(receiver.mem[0xA1], 0)
            self.assertEqual(receiver.mem[0xA2], 0)
            if key == 25:
                self.assertTrue(receiver.stopped)
            else:
                self.assertEqual(events, [key - 1, key - 1 + 0x20])


class SchedulerTests(unittest.TestCase):
    def test_two_keys_repeats_and_release(self):
        c = Controller()
        c.command("DOWN FORWARD", 0)
        c.command("DOWN WRIST_UP", 1)
        self.assertEqual(c.next_frame(), (2, False))
        self.assertEqual(c.next_frame(), (5, False))
        self.assertEqual([c.next_frame(), c.next_frame()], [(2, False), (5, False)])
        with self.assertRaises(ValueError):
            c.command("DOWN HOME", 2)
        c.command("UP FORWARD", 3)
        self.assertEqual(c.next_frame(), (2, True))
        self.assertEqual(c.next_frame(), (5, False))

    def test_tap_expiry_and_usb_lease(self):
        c = Controller()
        c.command("TAP ENTER 100", 0)
        self.assertEqual(c.next_frame(), (16, False))
        c.advance(99)
        self.assertEqual(c.next_frame(), (16, False))
        c.advance(100)
        self.assertEqual(c.next_frame(), (16, True))
        self.assertIsNone(c.next_frame())
        c.command("DOWN FORWARD", 200)
        c.command("PING", 1000)
        c.advance(2999)
        self.assertTrue(c.active)
        c.advance(3000)
        self.assertEqual(c.next_frame(), (25, False))
        self.assertEqual(c.next_frame(), (2, True))
        self.assertIsNone(c.next_frame())

    def test_stop_replaces_pending_and_saturation(self):
        c = Controller()
        for _ in range(16):
            c.command("DOWN 0", 0)
            c.command("UP 0", 0)
        with self.assertRaises(ValueError):
            c.command("DOWN 1", 0)
        self.assertFalse(c.active)
        c.command("STOP", 1)
        self.assertEqual(c.next_frame(), (25, False))
        self.assertIsNone(c.next_frame())

    def test_ticks_wrap_and_invalid_commands(self):
        diff = lambda a, b: ((a - b + 32768) % 65536) - 32768
        c = Controller(65000, diff)
        c.command("TAP 0 100", 65500)
        c.next_frame()
        c.advance(64)
        self.assertEqual(c.next_frame(), (1, True))
        for command in ("TAP 0 1", "TAP 0 BAD", "DOWN", "UP 1 EXTRA", "STOP EXTRA", "BAD"):
            with self.assertRaises(ValueError):
                c.command(command, 100)


class USBClientTests(unittest.TestCase):
    class Port:
        def __init__(self, error=False):
            self.lines = [b'MicroPython boot text\r\n', b'{"ready": true}\n']
            self.writes = []
            self.error = error
            self.closed = False

        def write(self, data):
            self.writes.append(data)
            if self.error:
                self.lines.append(b'{"ok": false, "error": "Unknown key"}\n')
            else:
                self.lines.append(b'{"ok": true, "command": "PING"}\n')

        def readline(self):
            return self.lines.pop(0) if self.lines else b""

        def close(self):
            self.closed = True

    def test_usb_line_exchange_and_startup_messages(self):
        port = self.Port()
        with patch("remote_cli.serial.Serial", return_value=port) as constructor:
            remote = Remote("COM5")
            self.assertTrue(remote.command("PING")["ok"])
            self.assertEqual(port.writes, [b"PING\n"])
            constructor.assert_called_once_with("COM5", 115200, timeout=0.2, write_timeout=2)
            remote.close()
            self.assertTrue(port.closed)

    def test_usb_error_response(self):
        with patch("remote_cli.serial.Serial", return_value=self.Port(error=True)):
            with self.assertRaisesRegex(RuntimeError, "Unknown key"):
                Remote("COM5").command("TAP INVALID")


if __name__ == "__main__":
    unittest.main()
