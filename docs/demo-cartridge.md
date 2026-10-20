# Sample demo cartridge

Analysis of the owner-supplied `cartridge.bin`, compared with the mapped main
firmware. Size: 4,096 bytes. SHA-256:
`db78d27d6660bfc08a9970ba0c72f7ce67216388c683d77820aa87740fc10be9`.

## Header and placement

The header contains entry pointer $A013 (`13 A0`) and the 17-byte string
`(c) 1985 CBS Toys` at offsets $0002–$0012. Its first four signature bytes
match the main firmware's cartridge discovery rule.

The absolute entry pointer and absolute loader reads indicate an intended CPU
mapping at $A000–$AFFF. Although the boot scan checks multiple boundaries,
this image is not position independent. Moving it requires relocation or
hardware mapping that preserves its $A000 addresses.

## Native 6502 loader

```asm
; CPU address $A013
    LDA #$02
    STA $02
    LDA #$82
    STA $03
    LDX #$00
copy:
    LDA $A035,X
    STA $0200,X
    LDA $A081,X
    STA $0500,X
    LDA $A0BB,X
    STA $0400,X
    INX
    BNE copy
    JMP $E0B6
```

| Cartridge source | RAM destination | Bytes copied | Purpose |
|---|---|---:|---|
| $A035–$A134 | $0200–$02FF | 256 | Program commands |
| $A081–$A180 | $0500–$05FF | 256 | Programmable speech slots |
| $A0BB–$A1BA | $0400–$04FF | 256 | Programmable tune |

The source ranges overlap. Each copy always transfers a full page, including
bytes after the respective data terminator. Consequently, not every copied
byte is meaningful program/speech/music data. Do not disassemble those trailing
bytes as additional robot commands or infer functionality from their appearance.

The loader returns to normal startup with a **jump** to $E0B6; it does not
directly call the command interpreter or write the mode byte $000D. The path
from its flag settings to automatic demonstration execution needs further
tracing. Its stores and final jump were verified with a small instruction-level
simulation of the loader: 2,054 instructions, all three page copies checked.
That simulation does not validate peripherals, timing, or physical execution.

## Program data

The meaningful stream occupies $0200–$024B: 37 opcode/operand pairs followed
by $FF $FF. The firmware recognizes $FF in the opcode position as end of program.
The owner reports that this format is the same as programming through LEARN
mode; firmware fetches at $E519 and editing routines support that interpretation.

| RAM | Opcode | Operand |
|---|---|---|
| $0200 | $83 | $10 |
| $0202 | $0C | $02 |
| $0204 | $83 | $00 |
| $0206 | $0C | $0A |
| $0208 | $83 | $16 |
| $020A | $0C | $01 |
| $020C | $83 | $17 |
| $020E | $0C | $01 |
| $0210 | $81 | $06 |
| $0212 | $0C | $0A |
| $0214 | $83 | $01 |
| $0216 | $0C | $01 |
| $0218 | $01 | $14 |
| $021A | $0C | $04 |
| $021C | $06 | $28 |
| $021E | $05 | $23 |
| $0220 | $0C | $03 |
| $0222 | $08 | $15 |
| $0224 | $09 | $00 |
| $0226 | $0C | $02 |
| $0228 | $0A | $01 |
| $022A | $0C | $07 |
| $022C | $0A | $00 |
| $022E | $03 | $06 |
| $0230 | $0C | $05 |
| $0232 | $82 | $3F |
| $0234 | $0C | $04 |
| $0236 | $83 | $02 |
| $0238 | $0C | $03 |
| $023A | $83 | $03 |
| $023C | $0C | $01 |
| $023E | $00 | $05 |
| $0240 | $0C | $02 |
| $0242 | $81 | $00 |
| $0244 | $0C | $02 |
| $0246 | $0B | $00 |
| $0248 | $02 | $14 |
| $024A | $FF | $FF |

Known dispatch behavior: $0C is delay, $81 selects a tune, $82 selects a sound,
and $83 selects a speech sequence. Movement-command meanings and operand units
are left unresolved here. Manual section 4.26 (PDF p. 19) subsequently confirmed
that delay operands specify 0–255 seconds; actual timing has not been measured.

## Programmable speech

$F40F computes $0500 + (index × 16) for speech indices $00–$0F. The first
four slots loaded by this cartridge contain these sequences, through their
first $FF terminators:

| Slot | RAM start | Sequence |
|---:|---|---|
| 0 | $0500 | `44 19 3E 8C 1B 8A FF` |
| 1 | $0510 | `44 19 68 83 8A 1E FF` |
| 2 | $0520 | `44 19 13 3E 53 04 43 6D FF` |
| 3 | $0530 | `3D 25 04 5B 8C 40 13 3D 2E FF` |

These slots are selected by `$83 00` through `$83 03` in the program. Other
slots are also overwritten by the page copy, but are not referenced by those
four commands. Speech indices $10 and above use the main firmware's ROM
sequence table. Actual spoken text requires further decoding or playback.

## Programmable tune

The tune at $0400 starts with duration/note pairs:

```text
70 12  70 11  38 0F  54 0D  E0 0F  00 00
```

The terminator occupies $040A–$040B. The main ROM's tune-0 pointer table refers
to $0400, and the demo program selects tune 0 at $0242 (`81 00`). Duration
units and note-to-frequency mapping remain to be documented.

See [Memory map](memory-map.md) for the biased program cursor, RAM state,
interrupt dispatch, and the distinction between confirmed facts and hypotheses.
