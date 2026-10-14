"""MicroPython/RP2040 USB CDC to Maxx Steele remote emulator."""

import sys
import time
import uselect
import rp2
from machine import Pin
try:
    import ujson as json
except ImportError:
    import json

import config
from controller import Controller
from protocol import pio_word


def make_program(inverted):
    @rp2.asm_pio(out_init=rp2.PIO.OUT_HIGH if inverted else rp2.PIO.OUT_LOW,
                 out_shiftdir=rp2.PIO.SHIFT_LEFT)
    def transmit():
        wrap_target()
        pull(block)
        set(y, 10)
        label("symbol")
        out(pins, 1)
        mov(x, isr)
        label("symbol_delay")
        jmp(x_dec, "symbol_delay")
        jmp(y_dec, "symbol")
        out(pins, 1)  # Physical idle, included in the packed word.
        out(x, 20)
        label("gap")
        jmp(x_dec, "gap")
        wrap()
    return transmit


class Transmitter:
    def __init__(self):
        if not 0 <= config.TX_GPIO <= 28:
            raise ValueError("TX_GPIO must be an available RP2040 GPIO")
        # Validate timing before enabling output.
        pio_word(1, symbol_us=config.SYMBOL_US, period_us=config.FRAME_PERIOD_US)
        self.pin = Pin(config.TX_GPIO, Pin.OUT, value=int(config.INVERT_OUTPUT))
        self.sm = rp2.StateMachine(config.STATE_MACHINE,
                                   make_program(config.INVERT_OUTPUT),
                                   freq=1000000, out_base=self.pin)
        self.sm.put(config.SYMBOL_US - 4)
        self.sm.exec("pull()")
        self.sm.exec("mov(isr, osr)")
        self.sm.active(1)

    def available(self):
        return self.sm.tx_fifo() == 0

    def send(self, key, release):
        self.sm.put(pio_word(key, release, config.INVERT_OUTPUT,
                              config.SYMBOL_US, config.FRAME_PERIOD_US))

    def close(self):
        self.sm.active(0)
        # Restore ordinary GPIO ownership and the physical idle level.
        self.pin.init(Pin.OUT, value=int(config.INVERT_OUTPUT))


def reply(value):
    print(json.dumps(value))


def run():
    tx = Transmitter()
    controller = Controller(time.ticks_ms(), time.ticks_diff)
    poll = uselect.poll()
    poll.register(sys.stdin, uselect.POLLIN)
    line = ""
    overflow = False
    reply({"ready": True, "device": "Maxx Steele remote", "gpio": config.TX_GPIO,
           "inverted": config.INVERT_OUTPUT, "symbol_us": config.SYMBOL_US,
           "period_us": config.FRAME_PERIOD_US})
    try:
        while True:
            # Bound input work so floods cannot indefinitely defer lease checks.
            for _ in range(32):
                if not poll.poll(0):
                    break
                char = sys.stdin.read(1)
                if not char:
                    break
                if char == "\r":
                    continue
                if char == "\n":
                    try:
                        if overflow:
                            raise ValueError("Line exceeds 96 characters")
                        if line:
                            reply(controller.command(line, time.ticks_ms()))
                    except (ValueError, TypeError) as error:
                        reply({"ok": False, "error": str(error)})
                    line, overflow = "", False
                elif len(line) < 96 and not overflow:
                    line += char
                else:
                    overflow = True
            controller.advance(time.ticks_ms())
            if tx.available():
                frame = controller.next_frame()
                if frame:
                    tx.send(*frame)
            time.sleep_ms(1)
    finally:
        # Ctrl-C/runtime failure: complete stop/releases when possible, then idle.
        controller.stop()
        start = time.ticks_ms()
        while time.ticks_diff(time.ticks_ms(), start) < 250:
            if tx.available():
                frame = controller.next_frame()
                if frame:
                    tx.send(*frame)
            time.sleep_ms(1)
        tx.close()


run()
