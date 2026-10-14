# Maxx Steele memory map

Working reference for the 1984 Ideal/CBS Toys Maxx Steele robot, its NCR ASIC
with a 6502 processor core, and cartridge development.

All addresses below are CPU addresses in hexadecimal. This is a partial map:
observed accesses establish individual register addresses, not their complete
decode ranges. Hardware mirroring, unused-space behavior, and the precise CPU
variant remain unverified.

## Evidence and conventions

- **Hardware report:** information supplied by the robot owner.
- **ROM verified:** bytes or behavior directly checked in the supplied mapped ROM.
- **Interpretation:** functional identification that still needs schematic tracing
  or bus measurements.

Sources: `Maxx_Steele_Main_Mapped.bin`, `MainDis_SGM.txt`, `Notes.txt`, and
`Maxx_steele_schematic.pdf`, supplied by the owner. The mapped image is 65,536
bytes with SHA-256
`d6359ba53a5072ecf2e8703cecda8c63bb9a47c8f39cd07dd047089b2f2c1746`.
Its bytes below $E000 are zero padding, not a dump of RAM or I/O.
The existing disassembly uses offsets relative to $E000: add $E000 to its
printed offsets to obtain CPU addresses. Its annotations and some byte entries
contain errors; the binary is authoritative.

The subsequently supplied `cartridge.bin` provides direct evidence of the RAM
program, speech, and tune layout. See [Sample demo cartridge](demo-cartridge.md)
for its loader and data analysis. Its relationship to LEARN-mode storage is
reported by the owner and supported by the firmware's editing/fetch routines.
The owner's `New_cartridge.bin` separates the same data into fixed source
windows suitable for a builder. See [Fixed-layout cartridge format](cartridge-builder-format.md)
for offsets, encoding limits, and its startup-mode caveat.

## CPU address space

| CPU addresses | Size | Assignment | Evidence / limitations |
|---|---:|---|---|
| $0000–$00FF | 256 bytes | Zero-page RAM | Part of the owner's reported 2 KiB RAM; extensively used by firmware |
| $0100–$01FF | 256 bytes | Stack page and other RAM data | 6502 stack; firmware also stores a startup marker at the bottom of this page |
| $0200–$07FF | 1,536 bytes | Remaining RAM | Hardware report; firmware uses several buffers here |
| $0800–$0FFF | 2 KiB | Unknown | Do not assume available RAM or cartridge space; decoding and aliases unverified |
| $1000–$1FFF | 4 KiB | Suspected ASIC I/O region | Individual accesses listed below; not proof that every address is decoded |
| $2000–$BFFF | 40 KiB | Candidate cartridge space; boot scan covers ten 4 KiB boundaries | ROM-verified scan at $2000 through $B000; electrical availability is a hardware hypothesis |
| $C000–$DFFF | 8 KiB | Candidate additional expansion space | Owner's proposed map; not searched by the cartridge boot routine |
| $E000–$FFFF | 8 KiB | Main firmware ROM | Hardware report and ROM-verified code, data, and vectors |

The scan granularity is not a cartridge-size restriction. A cartridge's actual
size and decode logic must be established independently. The Sanyo speech chip
is port addressed, and its LPC ROM is not CPU memory mapped. Speech vocabulary
addresses belong to that separate subsystem; see [Speech interface](speech-interface.md).

## Observed I/O addresses

These are individual addresses, not confirmed 512-byte peripheral blocks.
Read and write functions at the same address may differ.

| Address | Observed access | Firmware evidence | Working interpretation |
|---|---|---|---|
| $1000 | Read and write | $ED5F/$ED6C poll bit 6; $ED91 samples bit 0; $EC1B tests bit 7; $EEE2 writes | Serial timing/status and input; exact sources and write semantics unknown |
| $1200 | Read and write | Reset writes $00 at $E047 and $F8 at $E080; $ED69/$ED73 send serial patterns; $F483 tests input | Write bit 0: shared COP data; bits 1/2: head/other COP clock controls supported by sender patterns and schematic. Read bit 7: speech ready/busy; bit 6: game/sensor input |
| $1400 | Read and write | $F3F9–$F401 and $F467–$F471 output patterns; $FC96/$FCB5/$FCFD read during IRQ processing | Read bit 7: remote input. Write bits 0–3: speech nibbles; bit 4: address strobe; bit 7: Start pulse, verified in CPU traces |
| $1600 | Read and write | $EE36/$EEA2 test input; $F21D and $F4BF/$F4D3 write | Three numbered-lamp outputs supported by schematic and speech/music writes; exact output-bit mapping pending. Read bit 6: alarm path; read bit 7: battery path |
| $1C00 | Write observed | $F24A/$F252/$F25A/$F263 output values derived from note-frequency tables | Music/tone-generator programming candidate |
| $1E00 | Write observed | Reset at $E044, default NMI at $E017, and $EE7B write | System control: $00 on reset/NMI and $02 in sleep path; full semantics unknown |

In the serial routines, `BIT $1000` followed by `BVC` waits for bit 6 to
become **1**, and `BVS` waits for it to become **0**. Some supplied comments
describe these waits incorrectly. The transmit loop shifts the original
most-significant bit out first through bit 0 of writes to $1200. Receive code
samples bit 0 of $1000, accumulates eight bits, and complements the result.
This supports a serial-interface interpretation without establishing the
physical clock or selection wiring.

See the [complete I/O sweep](io-registers.md) for all 43 instruction sites,
read/write counts, width evidence, and unused-window limitations. No accesses
at $1800/$1A00 are identified, but neither is verified free.

Two VIAs are an owner hypothesis, not an established register map. Do not label
these addresses as standard 6522 registers until their behavior is demonstrated.

## Selected RAM locations

See [RAM ownership and API planning](ram-ownership.md) and the
[complete zero-page CSV](zero-page-map.csv) for the expanded per-byte map,
indexed-use caveats, and verified cold/warm cartridge-entry state.

| Address / range | Use | Confidence |
|---|---|---|
| $0056 | Eight-slot IRQ task index | ROM verified at $FDD0–$FDD7 |
| $005E | Serial output control pattern | ROM verified at $ED51–$ED64 |
| $005F | Serial transmit/receive shift byte | ROM verified at $ED4F–$EDAE |
| $0060 | Serial bit counter | ROM verified in the same routines |
| $0062–$0064 | Remote sampling counter, decoder state, and shift accumulator | ROM verified and replayed; see remote protocol document |
| $0065–$006A | Two held-key slots: full code, identifier, and age for each | ROM verified and replayed |
| $006B–$006E | Four-byte remote event ring | ROM verified |
| $006F–$0070 | Remote event-ring producer and consumer indices | ROM verified |
| $0075 | Remote event mailbox; $80 is normal no-event sentinel | ROM verified and replayed |
| $0072–$0096 | Startup table copied from ROM $E01C–$E040 | ROM verified at $E083–$E08B |
| $0076–$0077 | Writable NMI dispatch pointer; initially $E014 | ROM verified |
| $0078–$0079 | Writable IRQ dispatch pointer; initially $FDC8 | ROM verified |
| $007A–$007B | Mode dispatch pointer; initially $E0CB | Initial value and indirect jump verified; mode name from disassembly |
| $007C–$0083 | Eight IRQ task low bytes | ROM verified; entries are target-minus-one for RTS dispatch |
| $0084–$008B | Eight IRQ task high bytes | ROM verified; paired with $007C–$0083 |
| $008C–$008D | Dispatch pointer, initially $EE32 | ROM verified; full purpose unresolved |
| $008E–$008F | Cartridge probe pointer, then cartridge entry pointer; initially $1000 | ROM verified |
| $0090–$0091 | Dispatch pointer, initially $E598 | ROM verified; full purpose unresolved |
| $0092–$0093 | Dispatch pointer, initially $F3D8 | ROM verified; full purpose unresolved |
| $0094–$0095 | Dispatch pointer, initially $F8CE | ROM verified; identified as games entry in disassembly |
| $0100–$0110 | 17-byte copyright string used as a warm-start marker, copied from $E000–$E010 | ROM verified |
| $0200–$03FF | LEARN/program command storage, two bytes per slot | Firmware cursor and insertion limit support this range; demo loads only $0200–$02FF |
| $0400–$04FF | Programmable tune: duration/note byte pairs, ending with $00 $00 | Firmware and demo cartridge; $EF55 clears the page |
| $0500–$05FF | 16 programmable speech-sequence slots, 16 bytes per slot | $F40F selects $0500 + (index × 16) for indices 0–15; demo supplies sequences here; cold start fills with $FF |

### Program storage and interpreter state

| RAM address | Role |
|---|---|
| $0002 | Program/execution flags; demo initializes to $02; full bit meanings still being traced |
| $0003 | Feature flags; demo initializes to $82; full bit meanings still being traced |
| $000D | Mode: firmware identifies 1 as LEARN, 2 as program/edit, 3 as execute |
| $000F–$0010 | Little-endian biased program cursor; initialized to $0180 |
| $0011 | Current command opcode |
| $0013 | Current command operand |
| $0024–$0025 | Temporary cursor used while inserting/deleting program entries |
| $003B | Offset within programmable tune storage at $0400 |
| $0058–$0059 | Speech-sequence read pointer; may point to RAM or main ROM |

The cursor is biased by $80: $E519 reads the operand at `cursor + $81`,
then the opcode at `cursor + $80`. Thus initial cursor $0180 addresses the
first pair at $0200/$0201. $E41A advances the cursor by two; $E555 moves it
back by two, subject to a beginning-of-program check. $E2D6 checks the upper
cursor boundary $037E, corresponding to a pair at $03FE/$03FF. This establishes
a 512-byte command area, with room for 256 pairs including the end marker.
The owner's manual confirms **255 program steps**, numbered 000–254
(PDF page 14, Program Steps under section 4.2). Hardware execution at capacity
has not been tested here.

Each pair is `[opcode, operand]`. Opcode $FF marks the end; firmware tests the
opcode rather than requiring both bytes to be $FF. $E57B initializes an empty
program by writing $FF at `cursor + $80`. The demo terminates with $FF $FF.
These are interpreted robot commands, not native 6502 instructions.

The supplied firmware identifies $0C as a delay command, $81 as tune selection,
$82 as a sound selection, and $83 as speech selection. The command map is
incomplete. For speech, $F40F selects RAM slots for indices $00–$0F and ROM
sequences for higher indices; $FF terminates a sequence. The RAM contains
speech selection/control bytes, not the separate speech ROM's raw audio data.

### Manual-confirmed storage limits

The supplied `Maxx_Steele._manpdf.pdf` confirms the following limits. Page
numbers here are one-based PDF page numbers, not printed page labels.

| Storage | Usable capacity | RAM allocation / terminator | Manual reference |
|---|---|---|---|
| Program | 255 steps, numbered 000–254 | $0200–$03FF: 255 two-byte commands plus end pair | PDF p. 14, Program Steps, section 4.2 |
| User song (song 0) | 127 notes | $0400–$04FF: 127 duration/note pairs plus $00 $00 | PDF p. 24, section 4.61; p. 26, section 4.62A |
| User speech | 16 phrases, indices 0–15; 15 words per phrase | $0500–$05FF: sixteen 16-byte slots, each with 15 entries plus $FF | PDF p. 26, section 4.63 |
| Phrase pauses | Each pause consumes one word entry | Manual code 140 ($8C), about one second | PDF p. 27, section 4.63A |

Musical rests use the same tune-entry structure and consume song entries.
The manual describes approximately two minutes for 127 whole notes; that is
an approximate duration at the stated note lengths, not a separate byte
allocation or a measured timer limit.

The fixed-layout cartridge currently loads only $0200–$02FF and therefore
supports 127 command steps plus its terminator, despite the robot's full
255-step capacity. It loads the full song and speech allocations.

The stack grows downward from $01FF. The startup marker shares the stack page;
it is not a separate memory device. This table is not a complete RAM allocation.

### IRQ task dispatch

The default IRQ handler saves A/X/Y, calls $FC6F, cycles the index through
7 down to 0, pushes a task address from the split table, and executes `RTS`.
Consequently the stored words are **one less than the actual entry addresses**:

| Index | Stored word | Actual task entry |
|---:|---|---|
| 0 | $F1D8 | $F1D9 |
| 1 | $F1D8 | $F1D9 |
| 2 | $F1D8 | $F1D9 |
| 3 | $FDDF | $FDE0 |
| 4 | $EE94 | $EE95 |
| 5 | $EECF | $EED0 |
| 6 | $FDDF | $FDE0 |
| 7 | $F482 | $F483 |

$FDE0 restores the registers and executes `RTI`. The table is writable RAM,
but replacing entries requires preserving this calling convention.

## ROM layout and CPU vectors

| Address / range | Contents |
|---|---|
| $E000–$E010 | 17-byte ASCII `(c) 1984 CBS Toys`, without a terminator |
| $E011–$E013 | NMI trampoline: `JMP ($0076)` |
| $E014–$E01B | Default NMI handler: save A, write $00 to $1E00, restore A, `RTI` |
| $E01C–$E040 | RAM initialization/dispatch table |
| $E041 | Reset entry |
| $E090–$E0B5 | Cartridge discovery and dispatch |
| $E0B6 | Normal startup continuation after cartridge discovery |
| $FDC5–$FDC7 | IRQ trampoline: `JMP ($0078)` |
| $FDC8 | Default IRQ handler |
| $FFFA–$FFFB | NMI vector: bytes `11 E0`, target $E011 |
| $FFFC–$FFFD | Reset vector: bytes `41 E0`, target $E041 |
| $FFFE–$FFFF | IRQ/BRK vector: bytes `C5 FD`, target $FDC5 |

Vectors are little-endian. The supplied notes interchange NMI and IRQ and refer
to $FFFD alone as the reset-vector location; the complete reset vector occupies
$FFFC–$FFFD. The default NMI handler ends at $E01B, not at the reset entry:
the intervening bytes are initialization data.

## Cartridge discovery and header

Reset initializes the probe pointer to $1000, then increments its high byte by
$10 before each probe. It tests $2000, $3000, …, $B000 in ascending order and
stops before reading a header at $C000. Each candidate must have this header:

| Offset from cartridge base | Contents |
|---|---|
| +$00 | Absolute entry address, low byte |
| +$01 | Absolute entry address, high byte |
| +$02 | $28, `(` |
| +$03 | $63, `c` |
| +$04 | $29, `)` |
| +$05 | $20, space |

The comparison uses main-ROM bytes $E000–$E003; it does not match the complete
copyright string. The first matching candidate supplies the address for
`JMP ($008E)` at $E0B3. It is a jump, not a subroutine call: `RTS` is not the
boot-return mechanism. The firmware does not validate that the entry pointer
lies within cartridge memory.

Example: a cartridge at $2000 with code starting at $2006 has header
`06 20 28 63 29 20`.

Reset executes `SEI`, and no `CLI` appears before cartridge dispatch, so IRQs
are disabled at entry. A cartridge can explicitly jump to $E0B6 to continue
normal startup; compatibility with any changes it makes to RAM or peripherals
must be checked. A complete cartridge ABI is not yet established.

## Programmer offsets versus CPU addresses

The notes describe an 8 KiB 2365 ROM with a second chip select on socket pin 26
and pin 27 held high. Replacement-device image placements in those notes are:

| Device / image | Firmware offset in programmer image |
|---|---|
| Raw 8 KiB ROM payload | $0000–$1FFF |
| 27C128 replacement | $2000–$3FFF |
| 27C256 replacement | $6000–$7FFF |
| Supplied 64 KiB mapped analysis image | $E000–$FFFF |

These offsets do **not** relocate the firmware's CPU addresses. Pin behavior
and replacement compatibility must be checked against the specific device's
datasheet; the notes report the 27C256 arrangement working in a robot.

## Open questions for hardware validation

- Decode and mirroring of RAM, ROM, and individual I/O addresses.
- Actual cartridge chip-select, bus timing, and available address ranges.
- ASIC register bit assignments and whether any peripherals are VIA compatible.
- Which serial control patterns select the display COP and motor COP.
- Mapping of lamps, photocell, buttons, and remote serial input to ASIC pins.
- Speech command/status interface and separate speech-ROM addressing.
- Exact NCR CPU-core instruction set, including NMOS versus CMOS differences.

Until these are resolved, unknown regions should not be treated as safe scratch
RAM or unrestricted peripheral space.

See [Head display](head-display.md) for the raw segment masks, display update
stream, COP sender traces, and formatting scratch use of $24/$25. Those two
bytes are shared across subsystems rather than reserved display memory.

See [Remote-control protocol](remote-protocol.md) for the ROM-verified $1400
input bit, checksum, press/release encoding, key mapping, and remaining jack
and RF timing questions. A register access alone does not establish VIA hardware.

## Motor control follow-up

See [Motor control](motor-control.md) for the motor COP serial interface,
status and counter requests, and RAM $05–$2A roles. The main CPU maintains
positions and checks counter progress even though the COP handles local
motor hardware. $1000 bit 0 is sampled for serial replies; bit 6 gates the
serial timing waits. Bit 7 is tested in motor handshakes; remote input is instead read at
$1400 bit 7. The motor-status source remains unresolved.

## Cartridge connector follow-up

See [J400 pinout and control signals](cartridge-port.md) for the 44-terminal
connector, tentative NMIB identification, probable F2/Φ2 clock, and
BIGSPACEB expansion-select interpretation. Its decode boundaries remain
unverified. The speech-ROM interface is separate from the CPU bus.

## $C000–$DFFF firmware access audit

[Expansion access audit](expansion-accesses.md) finds no identified stock use
of this region for expanded program RAM. The apparent $DFFE operand at $E09F
uses Y=2–5 and compares $E000–$E003. Possible NMOS page-cross dummy bus reads
at $DF00–$DF03 remain hardware-dependent. Redirected command cursors can
reach modeled expansion RAM, but the stock storage limits and initialization
still require adaptation. BIGSPACEB direction and decode remain unresolved.
