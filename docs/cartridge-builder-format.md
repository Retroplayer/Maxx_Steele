# Fixed-layout cartridge format

Reference for a future Windows cartridge builder based on the owner-supplied
`New_cartridge.bin`. The builder is intended to let a non-programmer assemble
robot command sequences without editing native machine code.

## Verified image properties

- Size: 2,048 bytes ($0800).
- SHA-256: `99446cb88927f36e8f53c027baf549b5b37fb1b781f62ff649b1987114becf5a`.
- Intended CPU base: $A000; entry pointer: $A013.
- Signature: `(c) ` at file offsets $0002–$0005.
- Full header text: `(c) 1985 CBS Toys` at offsets $0002–$0012.
- Padding outside the header, loader, and meaningful data is $FF.

File offsets and CPU addresses are different: with this mapping,
`CPU address = $A000 + file offset`. Hardware must decode this 2 KiB image
appropriately; its electrical mapping and possible mirroring are unverified.

## Regions editable by the builder

| File offsets, inclusive | CPU source | RAM destination | Meaning |
|---|---|---|---|
| $0140–$023F | $A140–$A23F | $0200–$02FF | 256-byte command stream |
| $0340–$043F | $A340–$A43F | $0500–$05FF | Sixteen 16-byte speech slots |
| $0540–$063F | $A540–$A63F | $0400–$04FF | 256-byte programmable tune |

The $0200 spacing between starts does **not** make the copied regions 512 bytes.
The loader uses an 8-bit X index and transfers exactly 256 bytes per region.
The gaps and other offsets should remain unchanged in template-based output.
In particular, writing commands at $0240 and beyond will not extend the loaded
program with this loader, despite the firmware's larger RAM command area.

## Loader

```asm
; $A013
    LDA #$02
    STA $02
    LDA #$82
    STA $03
    LDA #$03          ; added relative to the original sample
    STA $0D
    LDX #$00
copy:                ; $A021
    LDA $A140,X
    STA $0200,X
    LDA $A340,X
    STA $0500,X
    LDA $A540,X
    STA $0400,X
    INX
    BNE copy
    JMP $E0B6        ; $A036
```

The loader occupies file offsets $0013–$0038. A small instruction-level
simulation verified 2,056 instructions, all three copies, flag values $02/$82,
mode $03, and the final jump to $E0B6. This validates the loader's memory effects,
not robot behavior or timing.

### Startup caveat

The loader sets execute mode ($000D = $03), but normal startup reaches $E0CB:

```asm
    CLI
    LDA #$80
    STA $75
    ASL A            ; A becomes $00
    STA $0D          ; mode becomes immediate ($00)
```

Therefore this mode store alone does not prove automatic execution. Startup
contains other paths and mode-dependent behavior before that point; trace them
or test on hardware before changing the return address or promising autoplay.
The uploaded image is preserved without modifying its code.

## Encoding and builder validation

### Robot limits versus this cartridge loader

The owner's manual (`Maxx_Steele._manpdf.pdf`) confirms:

| Resource | Robot limit | Current cartridge limit | Manual reference (PDF pages) |
|---|---|---|---|
| Program steps | 255, numbered 000–254 | 127, because only one command page is copied | p. 14, Program Steps under section 4.2 |
| Programmable song | 127 notes | 127 duration/note entries | p. 24, section 4.61; p. 26, section 4.62A |
| Programmable phrases | 16, numbered 0–15 | 16 | p. 26, section 4.63 |
| Words per phrase | 15, including pauses | 15 byte entries plus terminator | p. 26–27, sections 4.63 and 4.63A |

The builder should enforce the current cartridge limit for commands and the
manual limits for song and phrase content. It should count pauses as phrase
entries and rests as song entries. Expanding the loader to copy a second
command page would be needed to expose all 255 program steps; a larger ROM
file alone does not change these limits.

### Commands

Encode each command as two bytes: `[opcode, operand]`. Append `$FF $FF` and
fill the remainder of the 256-byte region with $FF. With this convention the
region holds at most **127 commands plus the end marker**. Firmware identifies
the end by opcode $FF; no user command should use that opcode as ordinary data.

This image has the same 37 meaningful commands and end marker as the original
demo. See [Demo cartridge analysis](demo-cartridge.md) for the complete list.
Verified dispatch categories include:

| Opcode | Function | Operand |
|---|---|---|
| $0C | Delay | 0–255 seconds according to manual section 4.26, PDF p. 19; timing not measured here |
| $81 | Tune selection | Tune index; $00 selects RAM tune |
| $82 | Sound selection | Sound index; valid index range still to be established |
| $83 | Speech selection | $00–$0F select RAM speech slots; higher indices select main-ROM sequences |

The builder should expose named commands and meaningful parameter controls once
the complete opcode map, units, and valid ranges are established. Until then,
retain raw byte values in the technical format without inventing movement names
or duration units. Raw byte operands must fit $00–$FF.

### Speech

Slot `n` starts at file offset `$0340 + 16*n`, for `n = 0…15`.
Encode its sequence bytes followed by $FF, then fill the rest of the slot with
$FF. This allows at most **15 sequence bytes plus a terminator per slot**.
These are speech selection/control bytes, not audio samples.
Manual section 4.63 confirms 16 phrases of up to 15 words. Section 4.63A
defines speech code 140 ($8C) as a pause of approximately one second and says
each pause counts as a word. A builder can expose this as a named Pause item
that consumes one of the phrase's 15 entries.

The first four meaningful sequences match the original demo. Slots 4–15 in
this image are filled with $FF. The old demo copied unrelated trailing source
bytes into unused slots; this image removes that spillover.

### Tune

Encode duration/note pairs, append `$00 $00`, and fill the remainder of the
region with $FF. This allows at most **127 pairs plus the two-byte terminator**.
The supplied tune contains five pairs:

```text
70 12  70 11  38 0F  54 0D  E0 0F  00 00
```

The tune matches the original demo. The manual confirms a 127-note limit and
gives duration choices of whole, dotted half, half, dotted quarter, quarter,
dotted eighth, eighth, and sixteenth notes (section 4.61, PDF p. 24). These
musical choices still need mapping to stored byte values before implementing
the builder's encoder. The manual's approximate two-minute capacity assumes
whole notes; entry count is the primary storage constraint.

### Export checks

1. Start from the verified 2 KiB template; preserve its header, loader, gaps,
   and bytes outside the three editable windows.
2. Reject overlength command streams, speech slots, and tune streams instead
   of truncating or allowing writes into adjacent regions.
3. Require the respective terminators within each window or slot.
4. Verify that the image remains exactly 2,048 bytes, with entry pointer $A013,
   matching boot signature, and unchanged loader bytes.
5. Read the output back and decode the three windows to confirm that they match
   the requested content before presenting it for programming.

For larger command programs, the loader must first be revised and validated to
copy additional RAM pages. For other cartridge base addresses, its absolute
entry pointer and source operands must be relocated. Neither is accomplished
by simply moving data in a generated file.

## Comparison with the original demo

| Property | Original demo | Fixed-layout image |
|---|---|---|
| Image size | 4 KiB | 2 KiB |
| Command source offset | $0035 | $0140 |
| Speech source offset | $0081 | $0340 |
| Tune source offset | $00BB | $0540 |
| Source windows | Overlapping | Separate |
| Copied bytes per region | 256 | 256 |
| Explicit mode store | None | $000D = $03 |
| Startup continuation | $E0B6 | $E0B6 |

The meaningful command bytes (including their terminator), first four speech
sequences, and tune pairs (including their terminator) match the original image.
The fixed windows make editing and validation simpler; they do not yet provide
a complete, hardware-validated command vocabulary.
