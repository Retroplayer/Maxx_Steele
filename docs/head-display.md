# Head display communication

The main ROM strongly confirms the owner's hypothesis: the CPU sends **raw
seven-segment patterns**, one byte per digit, rather than ASCII characters or
numeric digit codes. It computes glyphs and formatting before transmission.
The head controller drives the multiplexed four-digit display.

The trace tool executes the original CPU routines, including the serial
bit-shifting code. A modeled high/low reference at $1000 lets the polling loops
run; this does not establish physical clock timing or emulate the head COP.
Actual head-bus captures and the COP firmware are not available.

## Segment-byte format

The sixteen-byte glyph table at $F8BE–$F8CD is:

```text
Digit:  0  1  2  3  4  5  6  7  8  9  A  b  C  d  E  F
Mask:  FC 60 DA F2 66 B6 BE E0 FE E6 EE 3E 9C 7A 9E 8E
```

These patterns establish the conventional segment correspondence below.
`1` means the segment is requested on in the transmitted glyph; that does not
establish transistor-drive polarity at the LED pins.

```text
       a
     -----
  f |     | b
    |  g  |
     -----
  e |     | c
    |     |
     -----  • dp
       d
```

| Bit | Mask | Segment |
|---:|---|---|
| 7 | $80 | a, top |
| 6 | $40 | b, upper right |
| 5 | $20 | c, lower right |
| 4 | $10 | d, bottom |
| 3 | $08 | e, lower left |
| 2 | $04 | f, upper left |
| 1 | $02 | g, middle |
| 0 | $01 | Decimal-point indicator |

$00 is blank. $10 produces an underscore, not a minus sign; a middle-segment
minus would be $02 under this mapping. The firmware's 9 is $E6, omitting the
bottom segment. Some text glyphs use raised or stylized lowercase forms.

Decimal-point evidence is explicit: $F0ED loads $01 and $F0EF ORs it with
a digit glyph when the octave indicator is enabled. Tracing the music editor
with that flag off/on changes the first glyph from $FC to $FD while retaining
the other three bytes. The schematic also shows an eight-line segment matrix.

The supplied disassembly's suggestion that $F8BE is a music-frequency table
is misleading: this is a segment-glyph table, also used to format music-editor
displays. Audio pitch tables exist elsewhere.

## Display update stream

The preset and numeric display routines emit seven bytes:

```text
E3 F3  glyph0 glyph1 glyph2 glyph3  E2
```

- $ED48 transmits $E3, then falls through to transmit $F3.
- Four bytes follow through $ED4F.
- $F69F/$F6A1 finishes with $E2 through the same sender.

The prefix/suffix are verified CPU behavior. Describing $F3 as entering a
four-byte load and $E2 as applying/finishing that update is a useful working
interpretation, but exact command semantics require the COP firmware or bus
observations. $E3's independent effect is likewise unresolved. Glyph bytes
can themselves be $E0–$FF, so these values cannot be interpreted as commands
without context.

The numeric path sends high-order digits first. The physical digit-position
correspondence is strongly suggested by that formatting and the schematic's
MSD/LSD labels, but has not been observed with a head-bus capture.

For a zero-filled numeric display of 123, the stream is:

```text
E3 F3 FC 60 DA F2 E2     ; 0123
```

With leading-zero suppression it is:

```text
E3 F3 00 60 DA F2 E2     ; blank, 1, 2, 3
```

## Serial sender and head selection

| Routine | Role | Data-phase CPU write |
|---|---|---|
| $ED4F | Head byte sender | $1A or $1B to $1200 |
| $ED55 | Other COP/motor-path byte sender | $1C or $1D to $1200 |

Both shift the original most-significant bit first. Each bit waits for $1000
bit 6 to become high, writes the data phase, waits for bit 6 to become low,
then writes $F8 to $1200. The disassembly comments for some waits incorrectly
say that both wait for zero.

From these writes and the schematic's separate head/motor COP clock lines:

| $1200 bit | Logical role |
|---:|---|
| 0 | Shared serial data output |
| 1 | Head clock/control pulse: set in $1A/$1B, clear in $F8 |
| 2 | Other COP/motor clock/control pulse: set in $1C/$1D, clear in $F8 |

This supports shared data with separate clock controls, rather than assuming
an SPI chip-select line. Physical edge polarity, sampling edge, setup/hold,
and ASIC pin correspondence still need measurements. Head connector J100
includes signals labeled COPDATA and COPCKB. A COP model number cannot be
established reliably from the supplied schematic scan.

## Formatting routines and RAM

| Routine / data | Role |
|---|---|
| $F684 | Send one of 32 four-glyph preset messages, index in X |
| $F858–$F877 | First transmitted glyph for each preset |
| $F838–$F857 | Second transmitted glyph |
| $F818–$F837 | Third transmitted glyph |
| $F7F8–$F817 | Fourth transmitted glyph |
| $F737 | Convert operand $13 to packed BCD in $24/$25 |
| $F739 | Same conversion with value initially in A |
| $F6D6 | Four-digit numeric display, zero-filled |
| $F6D8 with X=$FF | Numeric display with leading blanks |
| $F6A4 | Mix command-specific label glyphs with operand digits |
| $F0D0 | Format music-editor note position, pitch, duration, and indicator |

$24/$25 are shared formatting scratch RAM, not permanent display RAM. The
four-digit numeric path reads nibbles in order `$25 high, $25 low, $24 high,
$24 low`. The BCD converter was checked for every operand 0–255. Both numeric
formatters were checked for every converted value.

There are also partial-label/control tables at $F878, $F889, $F897, and
$F8AA. These drive the mixed command/operand formatting path. The trace checks
23 command values ($00–$0F, $80–$84, $FE, $FF), each with five representative
operands (0, 1, 99, 140, 255), producing 115 recorded cases. This exercises the
formatter; it does not imply every operand is valid for every robot operation.
For example, the forward/42 formatter sends `E3 F3 8E 00 66 DA E2`, displaying
an F, blank, 4, and 2. Special $FE/$FF values select bEg/End, while $0B selects
the init preset regardless of operand.

## Preset patterns

All rows below were traced through the real serializer. Text is a readable
interpretation of the segment shapes, not ASCII sent on the wire. Raised
letter forms can differ from the capitalization shown.

| X | Glyph bytes in transmitted order | Approximate display |
|---:|---|---|
| 0 | B6 C6 C4 F6 | Song |
| 1 | B6 CE 9E 9E | SPEE |
| 2 | B6 9E 2A 1E | SEnt |
| 3 | B6 1E EE 1E | StAt |
| 4 | 2A 3A 1E 9E | notE |
| 5 | 9C 1C FC 9C | CLOC |
| 6 | 1C 9E 0A 2A | LErn |
| 7 | CE 84 C6 F6 | Prog |
| 8 | 00 0A 38 2A | run |
| 9 | CE 1C EE 76 | PLAy |
| 10 | 00 9C 1C 0A | CLr |
| 11 | 9C 1C 0A CE | CLrP |
| 12 | 8E 7C 1C 1C | FULL |
| 13 | B6 1E EE 1C | StAL |
| 14 | 00 9E 2A 7A | End |
| 15 | 00 3E 9E F6 | bEg |
| 16 | 20 2A 20 1E | init |
| 17 | EE 9E 3A 8E | AEoF |
| 18 | EE 9E 3A 2A | AEon |
| 19 | 00 B6 9E 0A | SEr |
| 20 | 00 CE EE 0A | PAr |
| 21 | CE 7A 3A 2A | Pdon |
| 22 | CE 7A 3A 8E | PdoF |
| 23 | 9E 7A 3A 8E | EdoF |
| 24 | 9E 7A 3A 2A | Edon |
| 25 | 7C 9C 3A 2A | UCon |
| 26 | 7C 9C 3A 8E | UCoF |
| 27 | 9E 3E 3A 2A | Ebon |
| 28 | 9E 3E 3A 8E | EboF |
| 29 | B6 CE 3A 2A | SPon |
| 30 | B6 CE 3A 8E | SPoF |
| 31 | 00 3E EE 7A | bAd |

## Evidence and remaining work

The [verification report](head-display-verification.json) includes all segment
masks, presets, numeric examples, decimal-point cases, and a complete $1200
write trace for the Program prompt. Every possible byte was checked through
both serial senders, reconstructing the byte from actual bit-phase writes.

```sh
cd /workspace/Maxx_Steele
/workspace/.venvs/maxx-steele/bin/python tools/analyze_head_display.py \
  --rom /path/to/Maxx_Steele_Main_Mapped.bin \
  --report /tmp/head-display-verification.json
```

Next checks: measure COPDATA/COPCKB while
showing known digits and a decimal
point. These can confirm timing, digit order, physical segment correspondence,
and the prefix/suffix semantics. The speech-ROM emulator is shelved; this work
does not change its hardware or the cartridge templates.

## Bounded pass through other head commands

The owner's working interpretation is that the head COP maintains clock/alarm
state and signals the main CPU through an alarm discrete. Main-ROM callers
support that interpretation: they send selection/adjustment commands, rather
than maintaining and transmitting complete hour/minute values. No deeper
clock-ownership investigation was undertaken.

| Head stream | Likely function / observed use | Evidence |
|---|---|---|
| E0 | Select/restore clock view | $E15C, $E697, and clock-key handling at $F796 |
| E1 | Select alarm view | Clock-key handling at $F79D–$F7B6 |
| E0 E8 | Advance clock hours | Key 0 path $F772–$F77A |
| E0 E7 | Advance clock minutes | Key 1 path $F77F–$F781 |
| E1 EA | Advance alarm hours | Key 2 path $F783–$F78A |
| E1 E9 | Advance alarm minutes | Key 3 path $F78F–$F791 |
| E1, then EB or EE | Alarm control when toggling software alarm flag $04 bit 7 | Key 6 path $F7A5–$F7B6; exact latch/enable effects provisional |
| EE | Alarm-event acknowledgement/control candidate | $EE3F/$EE41 sends it after alarm detection and clearing software flag |
| E5 | Head power-down/sleep request candidate | $EE78–$EE83 sends it during shutdown, then CPU spins indefinitely |
| E6 | Head initialization/wake request candidate | $E0B6/$E0B8 sends it during startup |

The four adjustment pairs were also executed through the original $F7D9
routine and serializer. That routine repeats the adjustment command while
waiting for another key, supporting held-button adjustment. Its time delays
were not converted to physical units.

The EB/EE toggle and acknowledgement uses do not establish a simple universal
on/off meaning for either byte. A head-COP trace would distinguish enabling,
clearing an alarm latch, and changing an indicator. Clock view and alarm view
are inferred from the user manual's key functions and their ROM callers.

Additional evidence: the schematic labels head signals for power, alarm,
alarm disable, and master reset, alongside COPDATA/COPCKB. Serial power-state
commands are therefore plausible, but the exact power-control implementation
is not proven. No independent head buzzer command was identified; the main CPU
starts its Reveille tune after handling the alarm signal.

**Sender identity matters.** $E4 and $E5 also appear in motor-control routines,
but those calls use $ED55, not the head sender $ED4F. They must not be assigned
head functions solely by their byte values. Likewise, the local Auto-Execute
toggle changes main-CPU flags and sends a display preset; it is not evidence
that the head COP executes robot programs.

This closes the bounded head pass with display loading, clock/alarm selection
and adjustment, alarm control, and likely initialization/power-down identified.
Detailed head command semantics and timing remain capture/COP-firmware questions.

## Readable LCD translation catalogue

See [all head messages and 1602 text suggestions](head-messages.md) for the
32 presets, command/operand labels, dynamic displays, manual-confirmed
option meanings, and a machine-readable glyph-to-text catalogue.
