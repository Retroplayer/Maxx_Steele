# CPU I/O sweep: $1000–$1FFF

The original-ROM sweep identifies **six addressed locations and 43 instruction
sites**. Every identified access uses an absolute address and transfers one
byte. There are no identified indexed I/O accesses or read-modify-write
instructions in this region. Counts below are static code sites, not the
number of accesses made while the robot runs.

| Address | Read sites | Write sites | CPU transfer width | Inferred function / implemented width |
|---|---:|---:|---|---|
| $1000 | 9 | 1 | 8 bits | Serial reply bit 0, timing bit 6, motor handshake bit 7; output used by headlamp service. Full hardware width unknown |
| $1200 | 3 | 9 | 8 bits | COP serial/control output; speech status bit 7 and game input bit 6 on reads. Full hardware width unknown |
| $1400 | 3 | 6 | 8 bits | Four speech-data output bits plus strobe/Start; receiver serial input bit 7 on reads |
| $1600 | 2 | 3 | 8 bits | Numbered-lamp outputs, likely three lines; alarm bit 6 and battery-status bit 7 on reads |
| $1C00 | 0 | 4 | 8 bits | Sound programming interface; several writes select/program internal state, not an identified single-byte tone register |
| $1E00 | 0 | 3 | 8 bits | System control: $00 on reset/NMI, $02 in sleep path. Only bit 1 is deliberately asserted in the identified writes |

Read and write functions at one address can differ. For example, $1400 bit 7
is **radio input on reads** and **speech Start on writes**. It is not evidence
of a single bidirectional external GPIO pin or a readback latch.

## Exact instruction sites

| Address | Reads | Writes |
|---|---|---|
| $1000 | E9F4, EA00, EC1B, ED5F, ED6C, ED82, ED8C, ED91, EDA0 | EEE2 |
| $1200 | F483, F91D, F963 | E047, E080, E907, E91D, ED69, ED73, ED89, ED99, EDA7 |
| $1400 | FC96, FCB5, FCFD | F3F9, F3FE, F401, F467, F46C, F471 |
| $1600 | EE36, EEA2 | F21D, F4BF, F4D3 |
| $1C00 | None identified | F24A, F252, F25A, F263 |
| $1E00 | None identified | E017, E044, EE7B |

Reads are `BIT` except `LDA` at ED91 and FCB5. Writes are `STA` except
`STX` at E044/E047 and `STY` at F401. No `INC`, `DEC`, `ASL`, `LSR`, `ROL`,
or `ROR` accesses target these locations in the audited instructions.

## Register sizes: what the code establishes

**CPU width:** all these transfers are eight bits. No consecutive addresses
are used as the low/high bytes of a 16-bit I/O register. No conventional
16-address VIA/PIA register bank is identified by the software accesses.

**Implemented bits:** the CPU's byte-wide transfers do not establish that
all eight bits are implemented. A three-output lamp latch or a one-bit control
can still be written with `STA`, which drives a full byte on the CPU bus.
Nor does a tested input mask establish that other bits are absent.

**Internal state width:** $1C00 receives multiple bytes per note. The three
channel-control bytes at $F2C0 are $90, $B0, $D0; the routine combines them
with frequency-derived values and emits a four-write sequence. This supports
an encoded sound-programming interface with internal state beyond the single
CPU address, but does not establish the exact counter width or chip identity.
An adjacent address is not implied by a multi-byte programming sequence.

$1E00's two observed values ($00/$02) establish use of bit 1 in the sleep
path, not a two-bit register specification. Its NMI write remains an observed
control/possible acknowledgement whose complete hardware effect is unknown.

## Additional bit-level findings

- $1200 bit 6 is tested at F91D/F963 using `BVS` in game code. A game/sensor
  input is established; correspondence to the photocell needs further tracing.
  Bit 7 is the speech-ready/busy test at F483.
- $1000 bit 7 is used in motor handshake paths. The remote decoder instead
  samples **$1400 bit 7** at FC96/FCB5/FCFD. Earlier motor notes assigning
  radio input to $1000 bit 7 were incorrect and have been corrected.
- $1000's write at EEE2 comes from the headlamp service, writing $00 or a
  value derived from `$82 XOR $71`. This does not make its read-side serial
  status bits available as ordinary output GPIO.
- $1600 receives full note/random bytes as well as $00, despite the schematic
  identifying only three numbered lamp outputs. [Chest-lamp analysis](chest-lamps.md)
  explains the competing writers.

## Unused addresses versus available hardware space

No direct stock accesses are identified at **$1800 or $1A00**, or at other
addresses besides the six listed above. The $200 spacing suggests that an
ASIC might select eight logical functions using A9–A11 while ignoring some
lower address bits. That is a decode hypothesis, not a demonstrated map.

There are two separate kinds of unknown:

1. Lower offsets such as $1001 might alias the function at $1000.
2. Entire apparently unused windows such as $1800–$19FF or $1A00–$1BFF might
   select unexercised ASIC functions, respond only to writes, or be undecoded.

Therefore **zero stock references is not sufficient to assign cartridge
hardware there**. The register access width also says nothing about decode
window size. A one-byte register can occupy a 512-byte mirrored window.

For cartridge planning, retain $1800 and $1A00 as candidate bases pending
hardware decode checks; keep the alternative I/O window outside internal
ASIC space. Checking readback alone cannot exclude an internal write-only
function. Read/write selection and any internal-versus-external data-bus drive
behavior must be established before accepting one of those bases.

## Scope and reproducibility

[Audit tool](../tools/audit_io_accesses.py) accepts the original mapped ROM
and supplied disassembly, with `--output` to write the
[full instruction report](io-access-verification.json). It checks 3,361 listed
instruction locations, using original binary bytes for opcodes and operands.
It also checks indexed bases below $1000 that could cross into the I/O region;
none were found. This is a static audit, not a cycle-accurate full-robot run.

The indirect-address inventory is included for pointer review. Normal pointer
sources examined in the [expansion audit](expansion-accesses.md) are program
RAM, tune/phrase RAM or ROM, and writable dispatch vectors. The boot pointer
starts at $1000 but is incremented before probing $2000–$B000, so it does not
read an I/O header at $1000. No normal indirect I/O access was identified;
custom or corrupt RAM pointers can still cause one. The listing is the code
location guide, so this is not proof that every possible executable path or
undocumented opcode has been found.

## ASIC package follow-up

The [U300 pin inventory](asic-pins.md) accounts for 67 drawn terminal
appearances with functional connections; some pin-number readings remain
ambiguous. It does not reveal two visibly spare eight-pin ports for the
$1800/$1A00 selections. Package allocation and address decoding are separate
questions.
