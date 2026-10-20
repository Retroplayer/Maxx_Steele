# Maxx Steele replacement remote controller

Bench-prototype firmware for a **bare ATmega328P**, replacing the entire COP411
controller/power board while retaining the keyboard PCB and 27 MHz transmitter.
Uses avr-libc directly; no Arduino core, bootloader, LTC2950, or external crystal.
The physical battery switch remains the master disconnect.

## Behavior

- Scan the owner's confirmed 6 × 4 matrix every 5 ms; debounce for 15 ms.
- Send press, held-repeat, and release frames with the original population-count
  checksum and two inverted separators. Support two simultaneous keys, sharing
  the RF frame stream by round robin; never send a third active key.
- POWER/STOP wakes the AVR and sends STOP; while awake it sends STOP without
  turning off the remote. A held STOP does not repeatedly generate new events.
  Keys suppressed by STOP or an ambiguous chord must be released before reuse.
- Reject potential diode-less matrix ghosting (three or more keys across rows).
- Control the power LED: on while awake, off in power-down.
- After **120 seconds** without keys or valid PC commands, finish the RF frame
  and gap, turn off transmitter power and LED, then enter AVR power-down sleep.
  The 120-second value is a new configurable default, not measured stock timing.
- Wake from POWER/STOP or UART RX activity. Other matrix keys do not wake it.
- PC-held keys require a valid command/heartbeat at least every **2 seconds**.
  Lease expiration sends STOP and clears all held commands. Physical keys alone
  do not require PC heartbeats. STOP also clears PC holds and inhibits currently
  held physical keys until release.

## Proposed wiring

Pin numbers below are for **ATmega328P DIP-28 only**. GPIO names are authoritative
when using another package. No claim of COP411 footprint compatibility.

| Function | AVR signal | DIP pin | Connection |
|---|---|---:|---|
| PC serial input | PD0 / RXD | 2 | USB-TTL adapter TX |
| PC serial output | PD1 / TXD | 3 | USB-TTL adapter RX |
| POWER/STOP Y | PD2 / INT0 | 4 | PK contact; other contact GND |
| Transmitter power | PD4 | 6 | Active-high input of high-side switch circuit |
| Power LED | PD5 | 11 | Series resistor and LED to GND; active high |
| Column L7 | PB0 | 14 | A/E/I/M/Q/U |
| Column L6 | PB1 | 15 | B/F/J/N/R/V |
| Column L5 | PB2 | 16 | C/G/K/O/S/W |
| Column L4 | PB3 | 17 | D/H/L/P/T/X |
| Transmitter data | PB4 | 18 | Base resistor to Q703-equivalent NPN |
| Row D0 | PC0 | 23 | A–D |
| Row D1 | PC1 | 24 | E–H |
| Row L0 | PC2 | 25 | I–L |
| Row L1 | PC3 | 26 | M–P |
| Row L2 | PC4 | 27 | Q–T |
| Row L3 | PC5 | 28 | U–X |

| Matrix row | L7 | L6 | L5 | L4 |
|---|---|---|---|---|
| D0 | A: left/0 | B: forward/1 | C: reverse/2 | D: right/3 |
| D1 | E: wrist up/4 | F: wrist down/5 | G: arms up/6 | H: arms down/7 |
| L0 | I: claw rotate/8 | J: claw open-close/9 | K: lamp | L: home |
| L1 | M: wait/note-rest | N: shift/octave | O: clear | P: enter |
| L2 | Q: notes/song | R: status/clock | S: speech | T: motion |
| L3 | U: game | V: program | W: learn | X: execute |

Rows are low only when selected; unselected rows float. Columns have internal
pull-ups. Y/YY is one separate ground-closing switch, not two keys. Button inputs
must be disconnected from the original battery-level power-latch circuitry.

### Supply, output stages, and programming

Supply VCC pin 7 and AVCC pin 20 with regulated **5 V**; GND pins 8 and 22.
Add 100 nF at each supply pin, bulk decoupling, and a RESET pull-up. The original
5.6 V rail exceeds the ATmega328P's recommended operating range. A low-quiescent-
current regulator stays powered during sleep; actual standby current includes
regulator, switch leakage, and board contamination and must be measured.

PD4 drives a **high-side switch interface**, not a P-channel MOSFET gate directly
at 9 V. Use a suitable level-shifting transistor stage. An external pull-down
must keep its logic input OFF while the AVR is reset/unpowered. The transmitter
continues to receive switched battery voltage, not the AVR's regulated 5 V.

PB4 drives an NPN through a base resistor (original Q703/R1 arrangement: 2N3904,
4.7 kΩ); emitter to GND, collector to DataOut, with the transmitter-side pull-up.
Add a base pull-down to prevent a floating output during reset. Never connect
the battery-level DataOut node directly to an AVR pin. **RF end-to-end polarity
has not been measured**: `INVERT_DATA` maps logical receiver symbols to base drive;
the transistor itself adds an inversion. Verify the receiver output with a logic
analyzer before operating the robot. `RF_SETTLE_MS` also needs measurement.
Default LED resistor can be 2.2 kΩ for modest current at 5 V, adjusted for the LED.

Reserve the normal ISP header: RESET pin 1, MOSI PB3/17, MISO PB4/18,
SCK PB5/19, 5 V, GND. The matrix shares MOSI and the base resistor loads MISO;
leave keys released during programming and ensure the RF switch stays OFF.
UART is **TTL-level**, not RS-232. Use a compatible adapter, common ground, and
prevent adapter pins from back-powering the AVR when the physical switch is OFF.
A USB adapter is optional; it is not part of the standby-current budget.

## UART commands

**38400 baud, 8N1**, newline terminated, case insensitive. Replies are plain text,
not the Pico emulator's JSON protocol. `OK` means accepted, not robot acknowledgment.

```text
HELP
KEYS
STATUS
TAP 1             # Forward, default 100 ms
TAP ENTER 150
DOWN 0            # Hold left
PING              # Repeat at <=1-second intervals while holding PC keys
UP 0
STOP
```

Comments above are explanatory; do not send the `#` comments. Keys accept the
canonical names printed by KEYS or PCB letters A–Y. Numeric names 0–9 are keypad
labels, not one-based wire IDs. Canonical names are:

```text
0 1 2 3 4 5 6 7 8 9 LAMP HOME WAIT OCTAVE CLEAR ENTER
SONG CLOCK SPEECH MOTION GAME PROGRAM LEARN EXECUTE POWER
```

TAP accepts 60–1500 ms. DOWN persists until UP, STOP, or PC lease expiration.
For longer holds, send PING every second. Physical/PC ownership is independent:
UP cannot release a key still held on the keyboard. Commands modify live desired
state rather than queueing macros; wait for each tap to complete before another
command for that key. At most two distinct ordinary keys may be active.
STATUS reports active and PC masks (bit 0 = A/key 0).

To wake over serial, send a disposable burst such as `UUUU`, wait **100 ms**,
then send a newline and `PING\n`. Wait for OK before sending movement commands.
The first characters may be lost/corrupt because the UART clock stops in
power-down. Cold boot prints READY; wake prints AWAKE. Abandoned partial lines
expire after one second. UART errors/overflows cause STOP and discard through
newline (or the partial-line timeout).

## Build and flash

Install GNU AVR GCC, avr-libc, binutils-avr, make, and avrdude. For Debian:

```sh
sudo apt-get install gcc-avr avr-libc binutils-avr make avrdude
cd remote-avr
make
```

Output: `build/remote.hex`. A prebuilt HEX is included in the downloadable ZIP.
Target is **ATmega328P at 8 MHz internal RC**, with CKDIV8 disabled; this is not
an Arduino Uno 16 MHz HEX. The firmware also explicitly clears CLKPR division.
A factory-fresh AVR's internal oscillator will work after correct clock setup,
but measure/calibrate OSCCAL if RF symbol widths or UART baud are inaccurate.

Example with USBasp and an otherwise blank, correctly identified ATmega328P:

```sh
avrdude -c usbasp -p m328p -B 10 -U flash:w:build/remote.hex:i
```

Clock and reset fuses must be checked separately. Proposed configuration:
low **0xE2** (internal 8 MHz, CKDIV8 off), high **0xD9** (ISP and RESET retained,
no bootloader), extended **0xFD** (2.7 V brownout detection). Confirm against the
exact chip datasheet/programmer before writing fuses. Do not disable RESET or ISP.
BOD is disabled only for sleep using the AVR's timed BODS sequence.

## Validation and limitations

Built successfully using AVR GCC 14.2.0 / avr-libc 2.2.1. Run:

```sh
make test
python ../remote-avr/tests/verify_frames.py --rom /path/to/Maxx_Steele_Main_Mapped.bin
```

The second check needs the project's py65 environment. It compares all 50 C++
press/release encodings to the existing Python encoder and all 23 receiver-capture
code sets, then feeds C++ symbols through the original robot ROM decoder at the
nominal transmission timing. All 25 keys pass, including repeat/release and STOP.
Lamp and STOP remain ROM-derived predictions without original remote captures.

Timer1 generates 11 × 1578 µs symbols plus an 11570 µs idle gap. Main-loop dispatch
and interrupt latency can add small delays; there is no claim of hardware timing
validation. Two held keys alternate frames, so each repeats about every 58 ms.
Timer0 provides milliseconds; UART input uses an interrupt-driven 63-byte ring.
No heap allocation. Timers and UART stop in power-down; timeouts restart from
wake, and no time-of-day is needed.

**Not flashed or tested on a remote yet.** Check both data polarities at the
receiver, keyboard scanning and chords, timing across battery/temperature,
POWER/STOP startup, UART wake, RF startup settling, and actual sleep current.
The owner-supplied schematic and lettered PCB photos establish wiring, not RF
polarity or original inactivity duration. Protocol evidence is documented in
[remote-protocol.md](../docs/remote-protocol.md).
