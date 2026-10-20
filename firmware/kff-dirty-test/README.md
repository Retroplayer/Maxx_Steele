# Original Kung Fu Flash → Maxx dirty test

Standalone firmware for the **original STM32F405RG / 8MHz-crystal KFF**.
Not Kung Fu Flash 2, an RP2040/RP2350 board, or a working full KFF port.
The source here is new; it uses the original KFF hardware's GPIO mapping.
Hardware reference: Kim Jørgensen's KFF commit
`7121a018c8608feafc2180d910ce58acddbec5e3`.

## First experiment

Serve a read-only 8KiB cartridge at **$A000–$BFFF** from STM32 SRAM.
The default image has the stock `(c) ` header and calls the verified main-ROM
routine at $F6D6 to display **1234**. It then loops at $A014 with Maxx IRQs
still disabled. The robot will not perform normal remote operation in this test;
pressing its reset repeats the test. No motor commands are issued by the payload.
The replacement head may format the digits according to its UI state.

This tests reads, including cartridge discovery, opcode fetches, and transitions
between stock ROM and cartridge. It does **not** test cartridge RAM writes,
USB console, SD loading, or simultaneous peripheral service.

`build/maxx-kff.bin` is STM32 firmware; `test-cart.bin` is the embedded 6502
cartridge image. **Do not interchange these files.**

## Wiring / flashing / test

See **WIRING.md** for the exact Maxx-to-original-KFF harness table and flashing
instructions. No KFF trace cutting is required for this mapping; unrelated KFF
contacts, including its transistor-driven reset contact, stay disconnected.

This is a candidate for bench measurement. It assumes **OEB low and WRB high**
identifies a valid read. Neither complete strobe timing nor Maxx 3.3V data-high
acceptance has been established. Match the actual board against the schematic,
check those signals, and use a logic analyzer or scope during the first test.

## Build

GNU Arm Embedded GCC, binutils, Make, Python3; no HAL, SDK, libc, or upstream
firmware checkout needed. Tested with GCC 14.2.1 (Debian gcc-arm-none-eabi).

```sh
make
# Or choose a toolchain explicitly:
make CROSS=/path/to/arm-none-eabi-
```

Outputs: raw BIN, Intel HEX, ELF, map, and annotated ARM disassembly under
`build/`. Flash starts at **0x08000000** and replaces existing KFF firmware.
There is no custom bootloader or KFF menu update format. Preserve a backup or
an appropriate original KFF release before erasing the device.

Optional custom test ROM (exactly 8192 bytes for A000–BFFF):

```sh
python3 make_image.py --image /path/to/rom.bin
make
```

To restore the default: `python3 make_image.py && make`.

## Implementation

- Original KFF address bus PB0–15; data PC0–7 through existing 100Ω resistors.
- PA0 = WRB (KFF R/W contact 5); PA8 = OEB (KFF PHI2 contact E).
- Clock PLL uses original 8MHz HSE to reach 168MHz, within F405 specification.
- Entire hot loop executes from SRAM. Image resides in SRAM; stack is in CCM.
- Data output latch is loaded **before** enabling the outputs.
- Address and strobes are checked again before driving. Outputs return to
  inputs on OEB deassertion, WRB assertion, or an address change.
- Outside A000–BFFF, and on writes, data pins stay inputs. No RAM writes yet.
- All interrupts stay disabled; no SysTick, USB, SD, display, or button task.
- PC13 LED is steady on once initialized. It does not count reads or prove
  Maxx accessed the cartridge. SWD remains available.
- HardFault/NMI handler attempts to release data pins, then stops.

This software polling loop has finite response and release latency. It cannot
prevent contention if OEB is unqualified or address/data turnaround is too short.
An address recheck cannot replace correct hardware strobe timing. Do not infer
that the code meets a timing budget simply because the CPU is fast.

## Verification

With py65==1.2.0 in a virtual environment:

```sh
python verify.py --main-rom ../../asm/build/main-rom.bin
```

The test boots the original 8KiB main ROM from its reset entry, finds the
cartridge, executes its display call with a synthetic COP timing input, checks
the exact output frame `E3 F3 60 DA F2 66 E2`, verifies no motor transmission,
and reaches its final loop. ARM checks verify vectors and SRAM loop placement
with no subroutine calls in that loop. See `build/verification.json`.

This simulation verifies 6502 behavior, not STM32 execution, electrical levels,
or physical bus timing. No hardware test has been performed here.
