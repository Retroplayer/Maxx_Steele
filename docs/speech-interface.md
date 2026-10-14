# Speech interface reverse engineering

The speech chip is controlled through CPU I/O ports. Its LPC start addresses
belong to the speech subsystem, **not the 6502 CPU memory map**. The speech
hardware reads the speech ROM; the CPU supplies address/control values. The
owner reports words in both the speech chip and external ROM, and support for
another speech ROM at the expansion connector.

## Hardware and verification scope

The supplied schematic identifies **U403 as LC8100** and **U402 as LC3100**.
It shows speech Start, Busy, and C0–C4 signals at the ASIC, plus A0–A3,
address strobe, data request, data output, and CT between the speech hardware
and ROM. The speech-ROM bus and audio output also reach J400, the cartridge
connector. Exact connector pin numbers and signal polarities need further
checking before hardware construction.

The subsequently supplied `LC8100.pdf` is a one-page Sanyo product overview
(printed page 26), covering both LC8100-series synthesizers and the LC3100 ROM.
Its feature lists and block diagrams confirm the capacities and addressing
capabilities below. It does not contain the functional timing, pin descriptions,
address-bit encoding, or LPC parameter format of a complete technical datasheet.
The file hash and source scope are recorded in
[speech-hardware-reference.json](speech-hardware-reference.json), separately
from the CPU trace report so the distinction remains explicit.

### Manufacturer-confirmed capabilities

| Capability | Evidence in the supplied overview |
|---|---|
| LC8100 synthesis | PARCOR voice synthesis; 9-bit D/A output |
| LC8100 internal parameter ROM | 32 Kbits, equivalent to 4 KiB of storage |
| LC3100 external ROM | 128 Kbits each, equivalent to 16 KiB of storage |
| External expansion | Up to 16 addressable LC3100 ROMs; 100 seconds of speech per ROM stated |
| Address width | 18-bit direct/address path in LC8100 diagram; 18-bit address counter in LC3100 diagram |
| Indirect vocabulary | 63 words; internal index/address table is 1,134 bits (63 × 18) |
| Direct vocabulary | Described as unlimited; still bounded by available speech storage |
| LC3100 selection | Four-bit chip-select decoder shown in block diagram |
| LC3100 data output | 1-, 4-, or 8-bit output lengths; serial and parallel output paths shown |
| Speech data rates | 2,400, 4,800, or 9,600 bits/second |
| Speech-speed options | −25%, normal, and +25% |
| Supply variants | 3 V low-power and 5 V high-power versions |

Storage equivalence does not by itself establish the direct interface's address
unit. The manufacturer diagram does establish that five transmitted nibbles
can accommodate the documented 18-bit address path; it is not a 20-bit address
space merely because the firmware writes five nibbles. The stock trace uses
zero high bits, so it cannot reveal all external ROM-selection encodings.

`tools/analyze_speech.py` executes the original CPU routines, records port
writes, and supplies modeled ready/busy status. It verifies all 140 address
entries, 17 main-ROM phrases, 16 RAM phrase pointers, the software pause, and
the launch latch. This does not emulate either speech chip or prove audible
playback. Word labels are transcribed from Appendix F, PDF page 34 of the manual.

## CPU port interface

| Port / bit | CPU behavior | Firmware evidence |
|---|---|---|
| $1400 bits 0–3 | Speech-address nibbles | $F460/$F465 and $F3D8 |
| $1400 bit 4 | Address strobe: 0 → 1 → 0, keeping nibble constant | $F467/$F46C/$F471 |
| $1400 bit 7, write | Start pulse: 0 → 1 → 0, keeping final nibble constant | $F3F9/$F3FE/$F401 |
| $1200 bit 7, read | High takes ready path; low takes busy path | $F483/$F486 |
| $1600, write | Numbered-lamp animation during speech; also written by music and cleared at completion | $F4BF/$F4D3; see chest-lamp investigation |

These describe CPU register transitions. Their levels at physical chip pins
still require datasheet/wiring confirmation. Read bit 7 of $1400 is the remote
input; the port's input and output functions are distinct. VIA hardware is not
assumed.

## Vocabulary addresses and transfer sequence

For vocabulary codes 0–139:

```text
low  = main_ROM[$F4DB + code]       ; table $F4DB–$F566
high = main_ROM[$F567 + code]       ; table $F567–$F5F2
address = (high << 8) | low
```

$F3D8 sends five nibbles, most significant first:

```text
0, high[7:4], high[3:0], low[7:4], low[3:0]
```

The leading zero and first three address nibbles each receive a bit-4 strobe.
The final nibble is presented during the bit-7 Start pulse, with no additional
bit-4 strobe. Each ordinary word therefore causes **four address strobes,
one Start pulse, and 15 writes to $1400**.

Code 0 (zero), encoded address $077E9:

```text
Nibbles:      0 7 7 E 9
Port writes:  00 10 00  07 17 07  07 17 07  0E 1E 0E  09 89 09
```

Code 65 (hello) selects address $00000. Its data nibbles are all zero, but
the strobes and Start pulse are still required. Address zero is a valid entry.
The five-digit addresses in this document are zero-extended values from the
two CPU tables. The supplied manufacturer diagram specifies an 18-bit direct
address path. Five nibbles provide 20 transmitted positions, but the exact
allocation of address, ignored, or control bits and the leading nibble's
latching semantics require the full functional specification.

The owner's recollection of three address bytes may describe a wider chip
interface: an 18-bit address requires three bytes to store in software.
This stock firmware visibly supplies five nibbles with a zero prefix and
two variable bytes through a four-bit interface. A sixth nibble must not be
added without checking the functional specification.

### Two address bands

| Encoded speech-address band | Entries | Examples |
|---|---:|---|
| $00000–$00FFF | 29 | hello $00000; my $00097; name $00176; I'm $005C3; I $00723 |
| $04000–$07FFF | 111 | a $04000; zero $077E9; steele $07D0F; hahahahaha $07DC4 |

This supports distinct stores and a selection role for address bit 14. Assigning
the low band to on-chip speech and the high band to the LC3100 is a working
hypothesis consistent with the owner's description. The confirmed 4 KiB internal
and 16 KiB external capacities also fit the observed 4 KiB and 16 KiB spans
under a byte-address interpretation. That is supporting evidence, not a
substitute for the full address-format specification. Address units and the
selection of a second external ROM remain unconfirmed. These values must not
be interpreted as CPU cartridge addresses.

See [speech-vocabulary.csv](speech-vocabulary.csv) for all codes, manual words,
encoded addresses, bands, and nibble sequences. No LPC payload is present in
the main CPU address tables, and word labels have not been checked by playback.

## Words, phrases, and robot commands

- Vocabulary codes 0–139 select individual LPC start addresses. Code 140 ($8C)
  is a software pause; $FF is the phrase terminator.
- Phrase indices 0–15 select 16-byte RAM slots at `$0500 + 16*index`.
- Phrase indices 16–32 select 17 main-ROM sequences at $F5F3–$F64D. $F40F
  scans $FF terminators to find them; there is no phrase-pointer table.
- Robot opcode $82 directly dispatches its operand as a sound/vocabulary index
  through $0092, initially $F3D8. Opcode $83 selects a phrase through $F40F.

RAM phrases hold 15 words/pauses plus a terminator. Their bytes are vocabulary
selectors, not LPC samples. The laugh at code 63 is another address-table entry.

| Phrase | CPU location | Manual vocabulary fragments |
|---:|---|---|
| 16 | $F5F3 | hello, pause, I, am, max, steele, pause |
| 26 | $F629 | I, need, energy, pause, please, re, charge, me |
| 29 | $F63C | sorry, pause, my, circuits, are, full |
| 31 | $F647 | please, program, me |
| 32 | $F64B | I'm, ready |

Fragments such as `re` + `charge`, `thir` + `teen`, and `win` + `zz` compose
longer words. The [verification report](speech-verification.json) lists all
17 phrases and each word's port-write trace with instruction addresses.

## Asynchronous servicing and RAM state

IRQ task slot 7 enters $F483. On ready status, a set $57 bit 7 prevents another
launch. A word launch sets that latch; a later busy observation clears it.
Only after ready returns can the service advance the phrase. The replay
confirms that a ready signal which never goes busy does not repeatedly consume
phrase entries.

When allowed, the service reads the next token through $58/$59, advances that
pointer, and dispatches through $0092. At end of phrase/direct sound it clears
$5B and writes zero to $1600.

| RAM | Meaning |
|---|---|
| $57 | Launch/busy-observed latch, bit 7 |
| $58/$59 | Little-endian phrase read/edit pointer |
| $5A | Software pause countdown |
| $5B | State: bit 7 phrase active, bit 6 pause active, bit 5 direct sound active |
| $5C | Evolving auxiliary value written to $1600 during busy processing |
| $5D | Auxiliary update divider, reset to $10 |
| $0092/$0093 | Writable low-level vocabulary dispatch vector, initially $F3D8 |

Code 140 sets $5A to $7A (122) and sets $5B bit 6 **without speech-port writes**.
The ready service counts down 122 eligible calls before clearing that flag.
The manual describes an approximately one-second pause; physical timing still
needs measurement. Slot 7 normally runs once per eight IRQ dispatches, so wall
time depends on the real IRQ rate and service conditions. The remote emulator's
chosen sampling interval is not a measured pause clock.

## Cartridge speech expansion

The connector exposes the speech-ROM bus separately from the cartridge CPU
program ROM. The stock routine always sends a zero prefix; its significance
for bank selection and loading remains unconfirmed. The manufacturer overview
confirms that up to 16 external ROMs can be addressed and shows a four-bit
chip-select decoder in the LC3100. It does not supply the actual ID programming,
selection-bit positions, or electrical bus-sharing rules.

The writable vector $0092 offers a firmware hook for a cartridge to replace
the vocabulary lookup or port sequence. It does not establish how another ROM
is electrically selected. Stock code is not a bounds-checked lookup for new
indices above 140, and $FF must remain the phrase terminator unless the phrase
interpreter is also replaced.

Before designing another speech ROM, establish:

1. LC8100 address-load/Start semantics, address units, and store-selection bits.
2. LC3100 address capture and data-request/CT/data-output timing.
3. Cartridge bank/chip selection and shared-bus electrical behavior.
4. LPC framing, coefficients, and end-of-word conventions for new content.

LPC decoding/new-word synthesis requires the speech-ROM data and chip-format
information; the main ROM's address table is insufficient. The supplied sheet
identifies PARCOR synthesis and data rates, but does not specify coefficient
quantization, frame packing, excitation encoding, or end markers.

See [Chest lamps](chest-lamps.md) for the deterministic blinking feedback,
music interference, and emulator-tested no-write patch candidates. The actual
ROM remains unchanged; speech latch/state operations must be preserved.

## Reproduce the checks

```sh
cd /workspace/Maxx_Steele
/workspace/.venvs/maxx-steele/bin/python tools/analyze_speech.py \
  --rom /path/to/Maxx_Steele_Main_Mapped.bin \
  --report /tmp/speech-verification.json \
  --words /tmp/speech-vocabulary.csv
```

The tool requires the known ROM hash and verifies all address transfers,
phrase pointers, the ready/busy latch, and pause countdown. Confidence is high
in these CPU behaviors; chip-internal decoding and bank selection remain open.
