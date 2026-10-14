# Head-display message catalogue for a 1602 replacement

The main ROM contains **32 fixed four-glyph presets**, plus command/operand,
numeric, and music formatting. These are segment patterns, not ASCII strings.
Spellings below are readable approximations of the original seven-segment
letter forms. All 32 streams were reverified through the original serializer.

The suggested LCD text is new wording. The CSV supplies two separate lines,
each checked to fit the 1602's 16 columns. Meanings combine ROM calling
contexts with the owner's manual, especially the display glossary and
sections 5.4–5.7 (PDF pages 29–34). This catalogue covers main-ROM output;
head-COP firmware-generated displays cannot be inventoried without that ROM
or additional observations.

## Fixed presets

| Index | Original display | Meaning | Suggested LCD (line 1 / line 2) |
|---:|---|---|---|
| 0 | `Song` | Song selection | Select song |
| 1 | `SPEE` | Individual speech sound selection | Select sound |
| 2 | `SEnt` | Sentence/phrase selection | Select sentence |
| 3 | `StAt` | Status/settings menu | Robot settings |
| 4 | `notE` | Direct note-playing mode | Play notes |
| 5 | `CLOC` | Clock menu/display | Clock |
| 6 | `LErn` | Learn mode | Learn mode |
| 7 | `Prog` | Program mode | Program mode |
| 8 | `run` | Execute mode | Run program |
| 9 | `PLAy` | Game mode | Play game |
| 10 | `CLr` | Clear a program step | Clear step |
| 11 | `CLrP` | Entire program cleared; manual also associates with clearing song | Memory cleared |
| 12 | `FULL` | Programming storage full | Memory full |
| 13 | `StAL` | Motor stall | Motor stalled |
| 14 | `End` | End of program | End of program |
| 15 | `bEg` | Beginning of program | Start of program |
| 16 | `init` | Initialize/home command | Return to home |
| 17 | `AEoF` | Auto-execution on alarm disabled | Auto execution / Off |
| 18 | `AEon` | Auto-execution on alarm enabled | Auto execution / On |
| 19 | `SEr` | Serial program execution | Execution mode / Serial |
| 20 | `PAr` | Parallel program execution | Execution mode / Parallel |
| 21 | `Pdon` | Automatic power-down enabled | Auto power-down / On |
| 22 | `PdoF` | Automatic power-down disabled | Auto power-down / Off |
| 23 | `EdoF` | Edit mode disabled | Edit mode / Off |
| 24 | `Edon` | Edit mode enabled | Edit mode / On |
| 25 | `UCon` | Wrist/arm coupling enabled | Wrist coupling / On |
| 26 | `UCoF` | Wrist/arm coupling disabled | Wrist coupling / Off |
| 27 | `Ebon` | Execute-backwards feature enabled | Run backwards / On |
| 28 | `EboF` | Execute-backwards feature disabled | Run backwards / Off |
| 29 | `SPon` | Verbal prompts enabled; not all speech enabled/disabled | Speech prompts / On |
| 30 | `SPoF` | Verbal prompts disabled; programmed speech remains distinct | Speech prompts / Off |
| 31 | `bAd` | Bad/invalid entry indication; precise context-dependent meaning | Invalid entry |

## Command labels followed by numeric operands

These are formatted by $F66C/$F6A4, rather than separate fixed strings for
every number. The labels were checked against the mixed-format trace report
and the manual's glossary. Blank positions vary with operand formatting.

| Original label/form | Meaning | Suggested LCD presentation |
|---|---|---|
| `L nn` | Left turn | Turn left / Amount: nn |
| `F nn` | Forward | Drive forward / Amount: nn |
| `b nn` | Backward/reverse | Drive backward / Amount: nn |
| `r nn` | Right turn | Turn right / Amount: nn |
| `Uu nn` | Wrist up | Wrist up / Amount: nn |
| `Ud nn` | Wrist down | Wrist down / Amount: nn |
| `Au nn` | Arms up | Arms up / Amount: nn |
| `Ad nn` | Arms down | Arms down / Amount: nn |
| `Cr nn` | Claw rotation | Rotate claw / Amount: nn |
| `Cco n` | Claw open/close | Claw / Open or Close |
| `HL n` | Headlamp on/off | Headlamp / On or Off |
| `d nn` | Delay in seconds | Wait / nn seconds |
| `Sn n` | Song number | Play song / Song: n |
| `S nnn` | Individual sound/vocabulary code | Speak sound / Code: nnn |
| `SS nn` | Sentence/phrase selection | Speak sentence / Sentence: nn |
| `PS nn` | Program speech / sentence to edit | Program speech / Sentence: nn |

`U` in the wrist labels approximates a W; `b`, `d`, and several other letters
use lowercase segment forms. Use action-specific units once the interpreter
has identified the command and valid operand; a glyph frame alone does not
prove that a numeric value has been validated.

Home command formatting uses the fixed `init` preset. Special beginning/end
command values use `bEg`/`End` rather than numeric operands.

## Numeric, music, and clock displays

- Program positions: 000–254, formatted from the biased cursor.
- Generic values: four numeric glyphs with zero filling or leading blanks;
  games also use this numeric path. Identical digits can have different meanings.
- Music editor: note position, pitch, and duration appear together. Letter
  glyphs represent the chromatic notes, with decimal-point patterns used in
  the encoding; the first-position decimal point marks the octave selection.
  The traced example is `00F3` with the first point off/on. Translate this
  into note number, named pitch/octave, and named duration when context allows.
- Clock/alarm: the CPU can select clock/alarm display and adjust hours/minutes
  through COP commands. The head COP maintains and formats its own time.
  The manual identifies the upper-left decimal point as PM in clock mode.
  A replacement must maintain this state, preserve alarm/wake behavior, and
  render something such as `Time 07:30 PM` or `Alarm 07:30 AM`.

Decimal points are context-dependent: the music octave indicator and clock
PM indicator must not be treated as one global meaning. Exact replacement
handling of COP-internal time/alarm functions remains separate work.

## Translation details that matter

- `Ebon/EboF` means **execute backwards on/off**, not error beep or echo.
  The manual explains that enabling this feature alternates forward/backward
  execution of the stored program.
- `SPon/SPoF` controls **verbal prompts**, not all programmed speech.
- `AEon/AEoF` enables/disables **automatic execution on alarm**; it is distinct
  from enabling the alarm itself.
- `UCon/UCoF` controls wrist/arm coupling, not a UART or USB connection.
- `CLrP` is used for clearing stored material; the manual associates the message
  with whole-program and whole-song clearing. The generic suggestion avoids
  inferring which storage was cleared from those four glyphs alone.

A replacement can recognize the complete four-byte preset tuple within the
`E3 F3 ... E2` frame. Decode framing first: high-valued glyph bytes can overlap
command byte values. Partial-letter matching is insufficient. For dynamic
numbers, keep display context when known and retain a raw-glyph/numeric fallback
when the stream does not uniquely identify a meaning. Future custom firmware
can add explicit text/message-ID commands to remove those ambiguities.

## Files and verification

[Machine-readable catalogue](head-messages.csv) includes the exact four glyph
bytes for every preset and the proposed LCD lines. Reproduce it with
`tools/export_head_messages.py ROM_PATH --output docs/head-messages.csv`.
The tool checks the ROM hash, executes all 32 presets, reconstructs the serial
bytes, and checks the 16-column line limits. The broader
[head-display verification](head-display-verification.json) covers numeric,
mixed-command, music-indicator, and clock-adjustment traces.

No ROM or head-controller firmware has been modified. Suggested wording is a
translation proposal, not proof that the original controller receives text.
