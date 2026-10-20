# Stock main-ROM assembly

This is a complete **KickAssembler 5.25** reconstruction of the supplied
Maxx Steele main ROM. It builds an **8,192-byte image matching the original
byte for byte**. The current source retains all stock features and addresses;
no game code has been removed and no code has been optimized or relocated.

Start with [main.asm](main.asm), the import list, and
[symbols.asm](symbols.asm), the documented RAM/port/vocabulary definitions.
There are 20 ordered includes under `includes/`. Address comments on every
instruction refer to the original CPU address, making it possible to compare
source, the old listing, traces, and hardware captures.

## Build

Java is required. On this workspace the tested assembler is installed outside
the checkout at `/workspace/.tools/kickassembler/5.25/KickAss.jar`.
From the repository root:

```sh
python tools/install_kickassembler.py
python tools/build_main_rom.py
```

The installer uses the c64lib KickAssembler release mirror and verifies the
pinned jar checksum before installing. Java 21 and KickAssembler 5.25 were
used for the verified build. The official distribution site was unavailable
from this environment; the mirror identifies itself as a copy of its releases.
The jar is not redistributed inside this repository.

For an explicit independent reference comparison:

```sh
python tools/build_main_rom.py --reference /path/to/Maxx_Steele_Main_Mapped.bin
```

Use `--jar /path/to/KickAss.jar` or the `KICKASS_JAR` environment variable to
select an existing installation. Paths are passed as structured subprocess
arguments; the wrapper also works with paths containing spaces. The build
wrapper itself uses only Python's standard library. The reverse-engineering
trace tools additionally need `py65==1.2.0`.

Outputs under ignored `asm/build/`:

- `main-rom.bin`: raw 8 KiB payload, CPU $E000–$FFFF, **no load-address header**.
- `main-rom-mapped.bin`: 64 KiB analysis image, zero padding below $E000.
- `main.sym`: assembler-generated symbol addresses.
- `assembler.log`: current compiler output and assertion results.
- `verification.json`: hashes, layout checks, and optional reference comparison.

The reference ROM is never an assembler input: there is no `.import binary`,
`.incbin`, embedded ROM file, or output copied from the original. Compilation
uses assembly instructions and explicit data directives. The reference is read
only after compilation, for comparison.

The wrapper enforces the stock hash, clears stale artifacts before building,
and checks assertion results explicitly because KickAssembler can report a
zero process exit status even when assertions fail. Intentional custom-ROM
changes will therefore require a separate build/verification policy; do not
change expected hashes simply to hide an accidental mismatch.

## Source organization

| Include(s) | Content |
|---|---|
| `00_boot` | Copyright, initialization table, reset, cartridge search |
| `10_modes_program`, `11_program_helpers`, `12_remote_ui` | UI modes, command storage/editor/interpreter, operand entry and mode keys |
| `20_motors` | Immediate/programmed motion, limits, coupling, home and positions |
| `21_cop_serial` | Head/motor serializer and motor reply reception |
| `22_service_power` | Polling, alarm/sleep, timers, headlamp service |
| `30_music` | User-song editor, three-voice playback, sound programming and effects |
| `40_speech` | Speech code, vocabulary addresses and phrase token data |
| `50_display`, `51_clock_settings`, `52_display_data` | Display formatting, BCD, clock menu, messages and glyph tables |
| `60_game_first`, `62_game_helpers`, `63_game_second` | Game code, state, parameters and helpers |
| `61_random` | Shared random-number helper retained outside game includes |
| `70_remote_rx` | Software radio decoder, checks, held keys and queue |
| `71_interrupts` | IRQ trampoline, save/dispatch/restore |
| `72_tune_data` | Tune pointer tables and duration/note streams |
| `99_vectors` | Hardware NMI/reset/IRQ vectors |

The filename suffix is `.asm` for every include. The order in `main.asm`
preserves the original layout. Each include has start/end assertions; those
assertions intentionally prevent accidental address shifts.

[routines.csv](routines.csv) inventories annotated entries and JSR targets.
It includes internal dispatch blocks as well as functions: **a named entry is
not automatically a safe cartridge API**. Some routines can change interrupt
state, reset the stack, tail-call, or leave through a mode vector.

## Coverage and what remains uncertain

[coverage.json](coverage.json) records:

- **3,362 actual instruction locations**, occupying 6,880 bytes.
- **1,312 data bytes**, expressed as text, byte/word tables, token sequences,
  tune streams, vectors, and six retained $FF fill bytes.
- **All 8,192 bytes accounted for**, with no opaque code-byte fallback.
- **607 distinct direct control-transfer targets** checked against instruction
  boundaries.

This is complete byte/instruction/data coverage, **not complete semantic
reverse engineering**. Some game helpers, flags, indirect paths, and NCR/COP
hardware behavior remain partly understood. Unknown helpers retain address
names such as `Routine_FB8C` rather than speculative names. Comments distinguish
established behavior from unresolved hardware meanings.

Corrections to the old listing include shifted instruction labels in
$E555–$E573 and the missing `BEQ` at $F07C. All emitted opcodes/operands and
branch destinations were decoded from the hash-checked binary rather than
copied from potentially incorrect printed bytes or branch annotations.

## Relocation-sensitive details

- The initialization table uses ordinary little-endian vectors and **split
  low/high IRQ task tables with target-minus-one values for RTS dispatch**.
- Music-effect handlers use another split RTS table, with low/high bytes loaded
  through several shared setup paths. Assertions require the handlers to share
  a high byte, matching the stock code's assumption.
- Several indexed lookup bases are biased addresses, e.g.
  `MusicNoteGlyphs-$F4` and `CopyrightText-2`. They are expressed symbolically;
  the apparent `$DFFE,Y` operand actually compares $E000–$E003.
- Music-duration lookup index zero reads the **RTS opcode $60 at $F15B**.
  This code/data overlap is retained and documented. Splitting/reorganizing
  that table independently will require deliberate rewriting.
- Speech addresses refer to external speech data, not CPU locations. Their
  constants stay in a separate `SPADDR_` namespace; ROM phrases use `VOC_` IDs.
- Page-$04/$05 storage and the biased command cursor retain fixed-layout
  assumptions. This is not a relocatable RAM ABI merely because names replace
  numeric addresses.
- Timing-sensitive polling loops and tiny sound-write delays preserve every
  opcode and byte position. No cycle-changing cleanup was performed.

Do not delete the whole game address range: `MusicRandomEffectIRQ` calls
`NextRandom` at $FA0C. The source isolates that helper in `61_random.asm` and
calls out its unconditional CLI. Reset also initializes the game vector, and
UI dispatch still offers game mode. A later game-removal change must update
those dependencies and audit shared helpers/data before releasing ROM space.

## Validation performed

The real KickAssembler build passes **46 assertions** and matches all 8,192
original payload bytes. Payload SHA-256:

```text
f232722d4773303b3e85bf3188af936735007207de8ce5ecc739bdd7348ebecd
```

The normalized mapped image matches the originally supplied hash:

```text
d6359ba53a5072ecf2e8703cecda8c63bb9a47c8f39cd07dd047089b2f2c1746
```

Existing trace checks were rerun **on the rebuilt mapped image**:

- Head display: all 32 presets, 256 BCD inputs, both serializers' 256 byte
  values, 115 mixed-format cases, octave point and clock/alarm adjustments.
- Speech: 140 vocabulary entries, 17 stock phrases, 16 user-slot pointers,
  busy/ready behavior and pause servicing.
- Motor control: 256 reply values, ten programmed operations, variants,
  coupling/gates, progress/stall branches, and completion counter updates.
- Reset/RAM: cold and warm startup through cartridge dispatch.

All four reports are identical to the original-ROM reports. See
[the saved verification result](../docs/stock-rom-assembly-verification.json).
These modeled peripheral checks do not emulate the COP programs or constitute
physical robot testing. The exact binary match is the strongest stock-baseline
check; modified ROMs will need additional targeted and hardware testing.

## Reconstruction tooling

`tools/reconstruct_main_rom.py` and `tools/rom_annotations.py` record how the
initial source was created. They require the original mapped ROM, old listing,
py65, and the repository's annotated RAM/message CSVs. They are reconstruction
utilities, **not required to compile the assembled source**.

To regenerate for review, choose a new scratch output directory:

```sh
python tools/reconstruct_main_rom.py \
  --rom /path/to/Maxx_Steele_Main_Mapped.bin \
  --listing /path/to/MainDis_SGM.txt \
  --output /tmp/maxx-rom-reconstruction
```

Compare generated files with curated source before accepting changes. Do not
blindly regenerate over hand-edited assembly or alter classifications solely
to make a byte comparison pass. Labels, symbolic pointer relationships,
comments, and code/data boundaries must remain reviewable.

Original uploaded ROM images remain untouched. Installing the rebuilt image
in OneROM or any hardware ROM replacement has not been performed here.
