# Kung Fu Flash as a Maxx Steele cartridge

## Conclusion

The original **STM32F405-based Kung Fu Flash (KFF)** is a credible alternative
prototype platform for Maxx's RAM/ROM/USB/SD cartridge. Reuse its assembled
hardware through a **fully remapped adapter**, and replace the C64 bus-serving
firmware and launcher with a Maxx-specific implementation. This is a schematic
and source review, not a hardware-tested adaptation or a ready-to-flash port.

The KFF board is not a pin-compatible Maxx cartridge despite the matching
44-contact mechanical format. Do not insert an unadapted KFF into Maxx.

Scope: upstream Git commit `7121a018c8608feafc2180d910ce58acddbec5e3`,
`hardware/KungFuFlash.pdf` (drawing revision 1), its XML netlist and firmware.
The preceding README advertises PCB revision 2. Check the actual assembled
board/revision against its own schematic; this review is not a claim about KFF2
or third-party clones. Upstream development has moved to Codeberg.

## What is already present

| Item | Evidence and use for Maxx |
|---|---|
| STM32F405RGT6-class MCU | Schematic specifies STM32F405RGTx; Cortex-M4 firmware operates at 168 MHz |
| Full address input | A0–A15 connect directly to PB0–PB15; one port read captures an address |
| Bidirectional data bus | PC0–PC7 through eight 100-ohm series resistors, RN1/RN2 |
| USB | PA11/PA12 and Micro-USB connector; upstream offers USB serial functionality |
| microSD | Dedicated SDIO wiring, not the cartridge bus |
| 3.3 V supply | AMS1117-3.3 from cartridge 5 V; no separate address/data translator ICs |
| Controls and programming | Menu/Special buttons, MCU Reset, LED, SWD, USB DFU |
| Memory | MCU has 1 MiB flash and 192 KiB RAM in distinct regions; sufficient capacity for the proposed 32 KiB robot RAM and 8 KiB ROM image, subject to firmware allocation |

KFF drives the host data bus at **3.3 V**, not 5 V. Its series resistors are not
level translators. Its implementation relies on the selected STM32 pin input
tolerance and C64 input thresholds. This is promising for avoiding a large
translator bank, but Maxx's ASIC must reliably accept the resulting output-high
level. Obtain the exact STM32 part's FT pin and supply-sequencing requirements;
C64 operation alone does not prove Maxx's electrical compatibility. In
particular, do not transfer this direct-connection approach to an RP2350.

## Remapping an existing KFF

This table describes **logical adapter wiring** between named KFF edge contacts
and the owner's corrected Maxx J400 signal numbers. It is not an insertion-side
or solder-side drawing. Verify orientation and continuity on the real boards.

| Maxx signal | Maxx J400 | KFF edge contact | KFF MCU |
|---|---:|---|---|
| A0 | 20 | Y | PB0 |
| A1 | 18 | X | PB1 |
| A2 | 17 | W | PB2 |
| A3 | 15 | V | PB3 |
| A4 | 13 | U | PB4 |
| A5 | 11 | T | PB5 |
| A6 | 9 | S | PB6 |
| A7 | 7 | R | PB7 |
| A8 | 8 | P | PB8 |
| A9 | 10 | N | PB9 |
| A10 | 16 | M | PB10 |
| A11 | 6 | L | PB11 |
| A12 | 5 | K | PB12 |
| A13 | 4 | J | PB13 |
| A14 | 3 | H | PB14 |
| A15 | 2 | F | PB15 |
| D0 | 22 | 21 | PC0 through 100 ohms |
| D1 | 24 | 20 | PC1 through 100 ohms |
| D2 | 26 | 19 | PC2 through 100 ohms |
| D3 | 28 | 18 | PC3 through 100 ohms |
| D4 | 25 | 17 | PC4 through 100 ohms |
| D5 | 23 | 16 | PC5 through 100 ohms |
| D6 | 21 | 15 | PC6 through 100 ohms |
| D7 | 19 | 14 | PC7 through 100 ohms |
| WRB | 12 | 5 (formerly R/W) | PA0, input |
| OEB | 14 | E (formerly PHI2) | PA8, input; proposed timer-capable strobe input |
| Switched 5 V, VSW | 41 | 2/3, same KFF 5 V net | Onboard regulator input |
| Ground | 1 and 43 | 1/22/A/Z, common KFF GND | Ground |

WRB's function is owner-confirmed. OEB's complete timing/qualification must still
be measured. PA8 is proposed for a Maxx read strobe; **it is not a claim that
OEB is a CPU clock or that the existing TIM1 configuration can remain**.
Additional controls could use KFF PA1/PA2/PA3/PA6/PA7 where appropriate.

Do not connect Maxx pin 39 (battery voltage) to any KFF logic input. Leave
F2, WEB, BIGSPACEB, RESET SYSB, and the speech bus unconnected initially. KFF's
GAME, EXROM, IRQ, NMI, and reset-driver outputs also stay disconnected unless
specifically repurposed after checking direction and firmware initialization.

The optional later NMI connection would be Maxx 35 to KFF D/PA10, operated
open-drain, after confirming that Maxx net. The KFF reset transistor cannot be
assumed useful: Maxx RESET SYSB is not established as an external reset input.

Under the provisional same-end face alignment in our C64 comparison, a raw KFF
would ground Maxx A15 and ASTRB, join other address contacts through its 5 V net,
and route Maxx battery voltage to a GPIO. These examples explain why an adapter
must remap **all** used contacts, not merely swap a clock or write signal.

## Firmware work

The stock firmware is not a general asynchronous memory emulator. It:

- Measures C64 PHI2 on PA8 with TIM1.
- Accepts a narrow PAL/NTSC period (160–170 ticks at a 168 MHz timer).
- Interrupts ahead of the expected CPU phase and uses cycle-counted delays.
- Decodes C64 ROML/ROMH/IO1/IO2 and handles VIC-II bus phases.
- Switches PC0–PC7 between input and output for each read.
- Uses a C64-native launcher and kernal hooks for several services.

A 2 MHz F2 signal would be about 84 timer ticks, outside that stock acceptance
window, and its CPU phase relationship is unknown. Feeding F2 to unmodified KFF
firmware does not solve the interface.

Replace the low-level handler with Maxx address decoding and measured WRB/OEB
handling. Only drive during selected reads, preload data before enabling its
outputs, and release promptly at read termination. Sample writes when the
actual bus data is valid. Strobe-triggered handling or a tight SRAM-resident
service loop are candidates; available setup/hold times decide which is viable.
Neither has been implemented or validated in this review.

Possible map, following our current cartridge plan:

| Address | KFF-backed function |
|---|---|
| $2000–$9FFF | 32 KiB emulated RAM |
| $A000–$AFFF | BASIC / cartridge bootstrap ROM |
| $B000–$BFFF | Monitor ROM |
| $C000–$DFFF | Selected mailbox/I/O registers, remainder reserved |

Put the original Maxx discovery header at $A000 with its proper absolute entry
pointer. Lower RAM pages must not accidentally present an earlier discovery
signature during boot. Leave internal RAM/I/O and main ROM ranges alone.

Store an initial bootstrap in STM32 internal flash, then copy to fast memory if
needed. Do not depend on reading a large SD file before the robot's one-time
cartridge scan. Maxx reset control is unresolved, so startup readiness must be
measured; a manual robot reset after KFF initialization is an initial test option.

Reusing USB, SDIO, and FatFs is realistic, but background service is a separate
real-time scheduling problem. The single STM32 core may be occupied serving
bus cycles. Bulk SD/USB operations may require an explicit robot-side handshake
and execution from internal ROM while bus service is paused. Stock KFF USB is
not advertised as continuously active in all cartridge modes. It is not evidence
that arbitrary simultaneous radio/audio/SD tasks will fit.

## Sleep and memory retention

Powering from Maxx VSW turns KFF off when that switched rail goes off. Its
emulated RAM is then volatile. Plan save/restore or a properly engineered
continuous supply if program retention across Maxx sleep is required. Do not
silently use the battery pin as a 5 V supply. When the MCU is unpowered but bus
lines remain driven, tolerance/injection/back-power behavior must be checked.
Keep KFF's USB-power jumper open when using robot power; the schematic shows a
jumper between USB VBUS and its cartridge 5 V rail, not power-source isolation.

## Recommended first experiment

1. Establish Maxx read-cycle width and address-valid/read-end timing from OEB,
   WRB, address, and data. Confirm 3.3 V data-high acceptance and voltage margins.
2. Build the remapping adapter, initially omitting uncertain controls and speech.
3. Install a minimal KFF firmware image that serves one 4 KiB ROM at $A000 and
   leaves the data pins floating everywhere else. No SD launcher or monitor yet.
4. Boot the stock robot into a tiny cartridge routine with an observable result.
5. Add RAM and a robot-side memory test, then USB/mailbox and SD services.

Confidence is high in the inspected KFF wiring and the need for a firmware port.
Feasibility is good at the architecture level. Maxx electrical thresholds,
strobe timing, startup, and sleep behavior remain hardware validation items.
This route is attractive if an assembled KFF is already available; it does not
replace the RP2350's extra memory, second core, and PIO advantages.

## Sources

- [KFF schematic](https://github.com/KimJorgensen/KungFuFlash/blob/7121a018c8608feafc2180d910ce58acddbec5e3/hardware/KungFuFlash.pdf)
- [KFF netlist](https://github.com/KimJorgensen/KungFuFlash/blob/7121a018c8608feafc2180d910ce58acddbec5e3/hardware/KungFuFlash.xml)
- [Bus GPIO and handlers](https://github.com/KimJorgensen/KungFuFlash/blob/7121a018c8608feafc2180d910ce58acddbec5e3/firmware/stm32f4xx/c64_interface.h)
- [Clock capture and synchronization](https://github.com/KimJorgensen/KungFuFlash/blob/7121a018c8608feafc2180d910ce58acddbec5e3/firmware/stm32f4xx/c64_interface.c)
- [Linker memory allocation](https://github.com/KimJorgensen/KungFuFlash/blob/7121a018c8608feafc2180d910ce58acddbec5e3/firmware/stm32f4xx/STM32F405RGTx_FLASH.ld)
- [Upstream Codeberg project](https://codeberg.org/KimJorgensen/KungFuFlash)
- Maxx connector: owner-supplied schematic and corrected WRB/OEB assignments,
  [recorded locally](cartridge-port.md). Unknown timing is not filled in by C64 assumptions.
