# Dirty-test wiring: Maxx to an ORIGINAL KFF

Use a passive C64 edge socket/breakout to reach KFF contacts, and the Maxx
protoboard for its connector. **Do not plug KFF directly into Maxx.**
Numbered/lettered KFF contacts below are original C64 designators, not a
sequential 1–44 numbering. Verify both connector orientations by continuity;
"front/back" alone is ambiguous. KFF GND is 1/A/22/Z; +5V is 2/3.
Maxx uses the owner's corrected **12 WRB, 14 OEB** assignments.

| Maxx contact | Signal | Original KFF contact | Destination |
|---:|---|---|---|
| 1 | GND | 1 / A / 22 / Z | GND |
| 2 | A15 | F | PB15 |
| 3 | A14 | H | PB14 |
| 4 | A13 | J | PB13 |
| 5 | A12 | K | PB12 |
| 6 | A11 | L | PB11 |
| 7 | A7 | R | PB7 |
| 8 | A8 | P | PB8 |
| 9 | A6 | S | PB6 |
| 10 | A9 | N | PB9 |
| 11 | A5 | T | PB5 |
| 12 | WRB | 5 (R/W) | PA0 |
| 13 | A4 | U | PB4 |
| 14 | OEB | E (PHI2) | PA8 |
| 15 | A3 | V | PB3 |
| 16 | A10 | M | PB10 |
| 17 | A2 | W | PB2 |
| 18 | A1 | X | PB1 |
| 19 | D7 | 14 | PC7 via original resistor |
| 20 | A0 | Y | PB0 |
| 21 | D6 | 15 | PC6 via original resistor |
| 22 | D0 | 21 | PC0 via original resistor |
| 23 | D5 | 16 | PC5 via original resistor |
| 24 | D1 | 20 | PC1 via original resistor |
| 25 | D4 | 17 | PC4 via original resistor |
| 26 | D2 | 19 | PC2 via original resistor |
| 28 | D3 | 18 | PC3 via original resistor |
| 41 | VSW +5V | 2 and/or 3 | Regulator input |
| 43 | GND | 1 / A / 22 / Z | GND |

Use a solid common ground, preferably several short ground returns alongside
the data/control bundle. Start with short wires (roughly 5–10cm where practical).
Retain KFF's existing eight 100Ω data resistors. They are not level translators.

**No other Maxx contacts connect in this test.** In particular leave Maxx
39 VBAT, 29 F2, 31 WEB, 33 BIGSPACEB, 35 NMIB, 37 RESET_SYSB, and the speech bus
isolated. No F2/PHI2 clock connection: KFF E receives **OEB**, not a clock.
All other KFF contacts stay isolated, including C (reset), 4 (IRQ), D (NMI),
8 (GAME), 9 (EXROM), 7/10 (IO1/IO2), 11/B (ROML/ROMH) and 12 (BA).

Fit a **10kΩ pull-up to KFF 3.3V** on each of PA0/WRB and PA8/OEB so loose
control wires inhibit output. These are harness pull-ups, not GPIO internal
pull-ups. Do not tie a control input directly to a rail.

## Power

For the actual test, use **Maxx switched 5V pin 41 → KFF 2/3** and shared ground.
**Leave J1 (KFF USB power jumper) open.** Disconnect USB and the programmer's
power feed for the robot-powered trial; this firmware does not provide USB CDC.
Never connect battery pin 39 to KFF. Never feed Maxx from USB through J1.
Avoid leaving bus signals driven into an unpowered board. For flashing with
USB power and J1 fitted, disconnect the entire Maxx harness first, then remove
J1 before connecting the harness again.

## Flash before connecting Maxx

Use STM32CubeProgrammer and an ST-Link on J4:

- SWDIO = PA13, SWCLK = PA14, GND common, 3.3V as target-voltage reference.
- J4 BOOT0 is not reset. Follow the actual J4 labels; do not assume probe pin order.
- Power KFF from USB using its documented power jumper arrangement while the
  Maxx harness is disconnected. Do not also power it from the probe.
- Save existing flash if needed, then program **build/maxx-kff.hex**, or program
  **build/maxx-kff.bin at 0x08000000**, verify and reset the STM32.
- No option-byte changes or readout-protection changes are needed.

The F405 ROM USB-DFU bootloader is another route: hold BOOT0 high at reset
using J4, connect USB and use CubeProgrammer's USB mode. Return BOOT0 low and
reset after programming. This is the silicon bootloader, not this firmware.

## First powered trial

1. Verify connector continuity, power polarity, and absence of accidental links.
   Remove any other cartridge. Keep motors mechanically clear during testing.
2. Check OEB/WRB waveforms and 3.3V input/output compatibility. This direct-bus
   arrangement follows KFF but Maxx ASIC input thresholds remain unmeasured.
3. Power up Maxx and the attached KFF. KFF LED steady on means firmware ready.
   Press **Maxx's head reset** once KFF is ready; initial boot may race startup.
4. Expect **1234** on the head, then a stationary test loop. The normal greeting
   and remote UI are intentionally bypassed by the cartridge. The onboard KFF
   buttons are unused; its reset button restarts KFF, not Maxx.
5. Scope OEB, WRB, address and data. A reset search should read header bytes
   **06 A0 28 63 29 20** at A000–A005, then fetch code at A006.
   After the display call, expect recurring JMP instruction fetches at
   **A014–A016 = 4C 14 A0** (6502 may also make dummy reads).
6. Confirm data is released before the next owner drives it. Measure worst-case
   response and release, including consecutive cartridge and main-ROM cycles.
   With no valid header, normal startup instead of 1234 is not a successful test.

Do not exercise sleep/power-off sequencing as a functionality test yet: VSW
switches off KFF while parts of Maxx remain powered. That compatibility is
outside this first experiment. Restore original KFF firmware before using it
in a C64 again.
