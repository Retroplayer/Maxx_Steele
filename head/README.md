# Head replacement prototype

Arduino firmware for a Waveshare RP2040-Zero (Pico Zero), 256 x 64 OLED,
and DS3231 RTC with CR2032 backup. A compatible RP2040-Zero clone must expose
the same GPIOs; confirm its power circuitry against its own documentation.
This is a bench prototype, not a tested drop-in head board. No robot ROM changes
are required. No COP firmware is emulated.

See [FUNCTION_AUDIT.md](FUNCTION_AUDIT.md) for the checked command coverage and
remaining compatibility gaps, including 12-hour/PM display, colon blinking,
and physical sleep/wake wiring.
Invalid-clock initialization is now implemented: see
[RTC_INITIALIZATION.md](RTC_INITIALIZATION.md). The hidden default calendar is
December 25, 1984 at midnight; no date or weekday is displayed.
The [context-aware UI notes](UI_BEHAVIOR.md) describe persistent mode labels,
large entry feedback, music and game-score interpretation, and the USB `u` demo.

## Build

Use the Earle Philhower **Arduino-Pico** board core, select **Waveshare RP2040 Zero**,
install **U8g2**, and open `MaxxHead/MaxxHead.ino`. USB is the serial console.
The environment used to create this prototype has no Arduino toolchain, so the
complete sketch has not been compiled or flashed. The portable receiver/parser
has been compiled and tested using the command below.

The display constructor is `U8G2_SH1122_256X64_F_4W_SW_SPI`.
The owner confirmed the purchased 2.08-inch OLED uses SH1122 and demonstrated
the previous sketch's display operation. U8g2 supplies a monochrome framebuffer even on supported grayscale
controllers. Software SPI avoids board-specific hardware SPI pin restrictions
and leaves a future hardware SPI peripheral available for reception.

## Wiring

See the [power-circuit investigation](../docs/power-circuitry.md) before wiring
sleep/wake outputs. Original VC is retained while VSW is switched; head POWERB
and ASIC POWER ENABLE B are separate signals. The prototype's optional power
output is not yet a verified electrical replacement for either connection.

| RP2040-Zero GPIO | Prototype function |
|---|---|
| GP0 | Robot COPDATA input, through 5 V to 3.3 V translation |
| GP1 | Robot head COPCKB input, through translation |
| GP2 | Alarm output interface, disabled by default |
| GP3 | Main-power switch control, disabled by default |
| GP4 / GP5 | DS3231 SDA / SCL (I2C0), pulled up to 3.3 V |
| GP6 / GP7 | OLED reset / DC |
| GP8 / GP9 / GP10 | OLED clock / CS / data |

Use a common ground. These are **GPIO numbers**, not physical pad positions or
robot connector pin numbers. All selected GPIOs are on the RP2040-Zero's edge
pads; GP16 is reserved for its onboard RGB LED. Pin assignments are centralized
in `MaxxHead/Config.h`, including the RTC I2C pins.

For a genuine Waveshare RP2040-Zero, the **5V pad** supplies the onboard 3.3 V
regulator. It is not named VSYS as on the full-size Raspberry Pi Pico. Supply
regulated 5 V and check the board's USB/external-power arrangement before
connecting both sources. Never apply 5 V to the 3V3 pad. A separate 3.3 V
regulator is only needed if the chosen peripherals exceed the board regulator's
available current or need a separate power domain.

OLED supply and signal levels must match its own documentation.
Do not connect robot 5 V signals directly to RP2040 pins. The original ALARMB
pull-up also requires an appropriate transistor/level interface before enabling
`DRIVE_ALARM`. Firmware releases the alarm pin when inactive and drives low
when active. `DRIVE_POWER` and polarity must be configured for the actual power
switch. Keep the MCU and RTC powered during robot sleep for this prototype.
The sketch polls the DS3231 alarm flag; INT/SQW wiring is not required yet.

## Bring-up

1. With robot inputs disconnected, check OLED output and USB console.
2. Send `n` repeatedly to cycle through all 32 translated stock messages.
3. Send `TYYYYMMDDhhmmss` to set the RTC, e.g. `T20261014213000`.
   A responsive RTC with its oscillator-stop flag set initializes to midnight
   automatically. USB date/time setting is optional, not needed for remote use.
4. `c` selects clock, `a` alarm view, `s` sleep, and `w` wake. With default
   configuration sleep changes only the display; it does not switch power.
5. Connect translated robot data/clock. Configure sampling mode, inversion, and
   bit order in `Config.h`. Modes 0/3 sample a rising edge; modes 1/2 sample a
   falling edge before optional inversion. This prototype uses **GPIO interrupts**,
   not a hardware SPI slave or PIO. It does not drive or enforce an idle clock.
6. Start reception before the main CPU starts transmitting. USB `r` discards
   partial data and treats the next edge as the first bit of a byte; use it while
   the sender is idle at a known byte boundary. There is no select line to repair
   a missed bit automatically. Optional gap reset must be based on measured gaps
   and defaults off. Queue overflow is reported and requires resynchronization.

## Implemented behavior

- `E3 F3` + four glyphs + `E2` commits an atomic frame. Glyph bytes are never
  mistaken for commands, even when they equal E3, F3, E2, or sleep commands.
- All 32 exact stock presets map to readable text generated from
  `docs/head-messages.csv`. Settings show their On/Off or Serial/Parallel detail.
- Recognized dynamic command/value frames show readable action labels and
  large values. Mode context persists in the footer; music and game formats are
  interpreted where possible. Unknown frames preserve the original segments.
- E0/E1 choose clock/alarm. E7/E8 advance clock minutes/hours without carrying
  into the other field. E9/EA advance alarm minutes/hours modulo 60/24.
- EB enables daily Alarm 1; EE disables/acknowledges and clears alarm flags.
  These are working interpretations of main-ROM callers, not COP-ROM verification.
  Alarm 2 is disabled when programming Alarm 1. Dedicated RTC ownership is assumed.
- E5 draws the sleep view then invokes the optional power output; E6 wakes.
  RTC Alarm 1 remains latched until EE and can assert the optional alarm output
  and power-enable. Alarm time and enable state are restored from RTC registers.
- Upper 49 pixels hold the message/clock/raw glyphs; the lower 15 show RTC and
  alarm status. Only these explicitly known states are shown, not an inferred
  persistent robot mode.

## Verification and limits

```sh
g++ -std=c++11 -Wall -Wextra -Werror -pedantic head/tests/protocol_test.cpp -o /tmp/maxx-head-test
/tmp/maxx-head-test
```

Tests cover all presets, command-valued glyphs, malformed frames, decimal-point
fallback, alarm/hour/minute wrapping, sleep/wake, parser reset, and all 256 byte
values for both bit orders and data polarities (1,024 receive cases).

Full Arduino compilation, interrupt timing, voltage interfaces, display fit,
and operation on Maxx remain unverified. GPIO interrupts must not miss clock
edges during display updates; validate with captures before relying on it.
The original head's other clock/reset/discrete connections are not reproduced
here, so do not remove the original board and assume this is a full replacement.
RTC I/O failures are not yet integrated into a complete fault-handling policy.

E-paper is not implemented in this sketch. Its renderer must wait until
the update is physically complete before calling `setPower(false)`. Custom
cartridge text and vocabulary-word text expansion are also future work;
no unverified extension bytes have been reserved on the legacy bus.
