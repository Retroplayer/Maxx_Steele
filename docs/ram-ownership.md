# Robot RAM ownership and cartridge API planning

The cartridge must coexist with firmware RAM state initialized **before** boot
dispatch. The stock reset path initializes vectors and music state before the
cartridge search; it does not finish every peripheral initialization before
calling the cartridge. Cold and warm reset also differ substantially.

A [byte-by-byte zero-page map](zero-page-map.csv) now covers all 256 locations,
with purpose, owner, confidence, cold/warm entry snapshots, and reference sites.
[Binary-checked RAM references](ram-verification.csv) and the
[verification report](ram-verification.json) preserve the evidence. Unknown
semantics are marked rather than assigned invented names.

## Memory regions

| RAM range | Owner / role | Cartridge policy |
|---|---|---|
| $0000–$00FF | Firmware variables, vectors, shared scratch, and candidate gaps | Allocate only after checking normal indexed/IRQ use; do not clear wholesale |
| $0100–$0110 | Seventeen-byte warm-start marker `(c) 1984 CBS Toys` | Preserve; changing it forces cold initialization on next reset |
| $0111–$01FF | Stack space above marker | Not ordinary workspace; CPU stack is fixed to page $01 |
| $0200–$03FF | LEARN/program pairs and terminator | Preserve unless explicitly replacing the user's program |
| $0400–$04FF | User tune duration/note pairs | Preserve unless editing/replacing the tune |
| $0500–$05FF | Sixteen user phrase slots | Preserve unless editing/replacing phrases |
| $0600–$07FF | No normal direct allocation identified | Candidate scratch/buffer area; availability not yet certified against every indirect path |
| Proposed $2000–$9FFF | Cartridge 32 KiB RAM | Preferred BASIC heap, program text, UART buffers, API state, and saved context |

The RAM marker shares the CPU stack page. It is not a stack guard: enough stack
usage can reach and overwrite it. Monitor/BASIC stack budgeting must include
ROM call depth and interrupt frames; the 17 marker bytes are not additional
stack capacity.

## Zero-page ownership by function

| Bytes | Role and coexistence implications |
|---|---|
| $00–$04 | UI/command, operation-result, program, feature, and alarm flags; bit meanings only partly decoded |
| $05–$0C | Motor status, direction, snapshots; $09 inhibit flags have an unresolved producer |
| $0D–$0E | Mode and command-entry submenu state |
| $0F–$10 | Biased command cursor; cold initialization sets $0180 |
| $11–$15 | Opcode, operation/note-duration index, operand, temporary value, foreground key |
| $16 | Clock/alarm adjustment repeat-acceleration counter at $F7DE/$F7E6/$F7EA |
| $17–$23 | Wheel speed, four position/counter triplets |
| $24–$25 | Editing pointer, packed BCD formatting, and game display scratch; routine-dependent |
| $26–$2A | Interrupt-driven timing/divider and delay counters |
| $2B–$30 | Three music active-state/duration pairs |
| $31–$36 | Three music stream pointers |
| $37–$38 | Tune-header pointer and sound-frequency scratch; foreground/IRQ sharing |
| $39–$3C | Music editing state; $3C semantics partial |
| $3D–$4E | Three music effect/envelope parameter sets; exact parameter names partly unresolved |
| $4F–$54 | Music effect dispatch low/high tables; RTS targets stored minus one |
| $55–$56 | Music effect mask and IRQ task slot |
| $57–$5D | Speech launch latch, phrase pointer, pause/state, lamp pattern/divider |
| $5E–$60 | COP serial control, shift register, bit count; shared transaction scratch |
| $61 | Candidate gap, not certified free |
| $62–$70 | Remote decoder, two held-key slots, event ring and indices |
| $71–$72 | Headlamp state/output shadow and divider |
| $73–$75 | Inactivity counters and remote foreground mailbox |
| $76–$95 | Firmware vectors, IRQ task tables, and cartridge entry/probe pointer |
| $96 | Battery status countdown/latch |
| $97–$A0 | Candidate gap, not certified free |
| $A1–$A3 | Remote framing, slot-overflow, and motor-stall diagnostics |
| $A4–$A5 | Pseudo-random shift state used by games/music |
| $A6–$AD | Game state; $AD is used through indexed initialization despite lacking an ordinary direct operand |
| $AE–$FF | Largest candidate zero-page area: 82 bytes; not yet a guaranteed allocation |

The distinction at **$AD** matters: searching only for literal `$AD` operands
would miss it. $F9DE loads X=7 and $F9E2 stores through `$A6,X`, clearing
$A6–$AD. Similar indexed accesses implement music parameter groups, remote
slots/rings, and interrupt tables.

Candidate ranges above total 93 bytes, but they are **not approved BASIC
zero-page allocations yet**. Their lack of fixed operands is an allocation
lead, not proof of non-use. Cold reset writes every zero-page byte, including
all candidates. They are not persistent cartridge storage across reset.

## What is initialized before cartridge entry

The verification executes the original reset code at $E041 until dispatch to a
synthetic cartridge at $B006, without running cartridge code. It seeds RAM with
$A5 so changes can be distinguished. A matching marker selects warm start;
a mismatching marker selects cold start. These are modeled RAM experiments,
not dumps of a running robot.

**Cold start:**

- Clears all $0000–$00FF at $E05E–$E064.
- Fills $0500–$05FF with $FF and clears $0400–$04FF.
- Initializes the biased program cursor and writes the first program terminator
  at $0200. It does **not** clear the entire $0200–$03FF allocation.
- Writes the marker at $0100–$0110.

**Both cold and warm paths:**

- Set the CPU stack pointer to $FF and leave IRQ disabled at cartridge entry.
- Set remote age bytes $67/$6A to $FF.
- Copy the table at $E01C–$E040 into $72–$96, replacing handler vectors and
  interrupt tables even on warm reset.
- Run music initialization at $EEEE before the search, modifying music state
  and programming sound output.
- Use $8E/$8F for probing and replace it with the matched cartridge entry.

**Warm start:** skips the bulk zero-page, song, phrase, and empty-program
initialization. Much firmware state is retained. The `$A5` entries in the warm
snapshot demonstrate preservation; they are not recommended live state values.
Do not assume that all firmware variables are freshly zeroed at entry.

The modeled reset preserves the seeded $0600–$07FF contents in both paths.
That result does not establish that no later routine can touch that range.

## Writable vectors and initial values

| Address | Cold/warm reset value | Function |
|---|---|---|
| $76/$77 | $E014 | NMI handler |
| $78/$79 | $FDC8 | IRQ handler |
| $7A/$7B | $E0CB | Mode return / normal foreground entry |
| $7C–$83 and $84–$8B | Eight split target-minus-one entries | IRQ task dispatch |
| $8C/$8D | $EE32 | Foreground service dispatch |
| $8E/$8F | Initially $1000, then matched entry | Cartridge probe/entry |
| $90/$91 | $E598 | Command-input dispatch |
| $92/$93 | $F3D8 | Low-level speech vocabulary dispatch |
| $94/$95 | $F8CE | Game dispatch |

Reset restores these hooks. A cartridge must reinstall any custom vectors on
each entry. The default IRQ saves registers, runs the receiver, and dispatches
one of eight tasks. Replacing a task entry requires its existing stack/RTI
convention; it is not equivalent to an ordinary `JSR` callback.

## API design consequences

1. **Keep cartridge state in expansion RAM.** UART buffers, BASIC variables,
   monitor state, and API context should not consume robot buffers or live
   IRQ state. Zero page is needed for efficient addressing, but its allocation
   must be an explicit contract rather than an assumption.
2. **Do not save/restore all firmware zero page around calls.** That would roll
   back elapsed timers, received events, phrase progress, and other legitimate
   asynchronous state. Preserve only documented caller-owned scratch.
3. **Specify a call's effects beyond A/X/Y.** Document parameter bytes, scratch
   clobbers, persistent state changes, asynchronous work launched, required
   service routines, and completion/error reporting.
4. **Serialize shared peripheral transactions.** COP calls use $5E–$60, and
   interrupt music work can also call the head serializer. Choosing a critical
   section or service-ownership scheme requires checking receiver timing and
   the exact routine; a blanket long interrupt-disable policy is unsuitable.
5. **Treat interrupt state as part of the ABI.** Some routines do not preserve
   it: the pseudo-random helper at $FA0C uses `SEI` then unconditional `CLI`.
   Returning from a wrapper with restored P does not prevent interrupts during
   an inner routine that executes `CLI`.
6. **Preserve user data by default.** Motion, display, and speech API calls
   should not silently reset the LEARN program, tune, or phrase buffers.

## Starting API entries to audit

These are research candidates, not a promised callable ABI:

| Routine | Preliminary interface | RAM / lifecycle considerations |
|---|---|---|
| $E9FE | A=motion operation, $13=operand | Updates $05–$23, uses serial scratch; handshake may service other subsystems |
| $EDAF | Motor/service polling | May detect stall and leave via mode vector rather than return normally |
| $F684 | X=display preset | COP scratch; display is also written by other foreground/music paths |
| $F6D6 | Format/display number | Shared $24/$25 formatting state and serial scratch |
| $F40F | X=phrase index | Installs speech pointer/state; playback depends on IRQ servicing |
| $F3D8 | X=vocabulary index | Speech-port transaction and launch latch; busy handling matters |
| $EF01 | X=tune index | Replaces music state/pointers; playback depends on IRQ servicing |

The next API work should audit each selected entry for parameter/setup
requirements, exit paths, stack usage, register/flag clobbers, and IRQ-driven
RAM changes. This ownership map supplies the common reference for that work.

## Reproduction and remaining limits

`tools/audit_ram.py` accepts the mapped ROM, supplied listing, and `--output`.
It generates the JSON reset/reference report and the reference CSV.
`tools/export_zero_page_map.py`, run from the repository root after the audit,
combines that report with the manually annotated roles to generate the
byte-level map.

The RAM audit rejects opcode mismatches in the supplied listing and redecodes
$E555–$E573 from binary boundaries. The listing's shifted labels otherwise
produce a false `ORA ($C5,X)` reference. **No real $C5 use is established by
that listing artifact.** Static indexed operands are recorded as bases, not
claimed as complete effective-address sets. Some game/music semantics and
configuration bits remain partial, and unknown bytes are not declared free.

### Clock-menu correction

The display-message follow-up identified a missed annotation: $16 is used
by the clock/alarm adjustment routine $F7D9. The reference CSV already
contained these accesses; the earlier manual role annotation incorrectly
called it a candidate gap. It is now reserved for the clock UI.
