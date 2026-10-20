# Stock firmware accesses to $C000–$DFFF

No deliberate stock use of this region for program storage, RAM detection,
or cartridge discovery has been identified. The only explicit address operand
in this range in the audited instructions is `$DFFE` at **$E09F**. Its actual
indexed comparison reads main ROM, with an important possible dummy-bus-read
exception described below.

This audit checks 3,361 instruction locations identified by the supplied
`MainDis_SGM.txt`, decoding their actual opcodes/operands from the original
mapped binary. It also considers absolute indexed operands just below $C000
that could cross into the region, and inventories indirect addressing.
It is not an exhaustive proof over every possible execution path, malformed
program, modified RAM pointer, or undocumented ASIC bus cycle.

## The apparent $DFFE read

The cartridge scanner contains:

```asm
$E090: LDY #$05
       ; increment candidate base by $1000
       ; stop when candidate high byte reaches $C0
$E09D: LDA ($8E),Y
$E09F: CMP $DFFE,Y
       ; compare candidate signature, decrement Y down through 2
```

The signature comparison uses Y=5,4,3,2, giving effective addresses
**$E003, $E002, $E001, $E000**. These are the stock `(c) ` signature.
It does not compare bytes at $DFFE/$DFFF. The scanner stops before probing
$C000, so no header at $C000 or $D000 is discovered by this code.
Original-ROM execution with a matching header at $B000 verifies the four
comparison addresses and reports no architectural $C000–$DFFF accesses.

**Physical bus caveat:** an NMOS 6502 absolute-indexed read crossing a page
boundary normally performs an extra read with the uncorrected high byte.
For these instructions the intermediate addresses would be **$DF03, $DF02,
$DF01, $DF00**. The NCR core's bus behavior is unverified, and py65 does not
model those bus transactions. Thus a logic analyzer could show reads in the
$D000 region at startup even though the comparison consumes main-ROM data.
If BIGSPACEB selects $C000–$DFFF, it might assert during those dummy reads.
That is a testable possibility, not a measured result.

## Indirect addressing and normal pointer sources

| Pointer(s) | Use | Stock source / location |
|---|---|---|
| $8E/$8F | Boot header reads, then cartridge entry | $2000 through $B000 candidate bases; matching header supplies jump address |
| $0F/$10 | Command reads and writes | $E582 initializes biased cursor $0180; command area $0200–$03FF |
| $24/$25 | Program insertion/deletion and temporary calculations | Copied from command cursor in editing paths; also general scratch RAM |
| $37/$38 | Tune header read | Nine stock header pointers at $FDFE–$FFB0 |
| $31/$32, $33/$34, $35/$36 | Three tune-stream read pointers | Stock tune headers supply $0400 or main-ROM addresses |
| $58/$59 | Speech-sequence reads and editing writes | User phrases $0500–$05FF or main-ROM sequences starting at $F5F3 |
| $76/$78/$7A/$8C/$90/$92/$94 | Indirect control transfers | Initialized to main-ROM handlers; writable by cartridge code |

The audit records all listed indirect instructions in its report. No normal
pointer initializer examined here selects $C000–$DFFF. However, a cartridge
can supply an entry address in that region, redirect a writable handler vector,
or change data pointers. Consequently, the ROM's absence of literal $C000
operands does not prevent custom firmware from accessing expansion memory.

## Existing routines can fetch and store expansion commands

A targeted original-ROM test sets the biased program cursor to **$BF80**,
so `cursor + $80` addresses $C000. With modeled RAM at $C000:

- **$E519** reads the operand at $C001 ($E51B) and opcode at $C000 ($E520).
- The pair-store portion beginning at **$E335**, entered with Y=$80,
  writes opcode to $C000 and operand to $C001, then advances the cursor by two.
  The trace stops before the display routine at $F64E.

This demonstrates the existing primitive operations can reach that address;
it does **not** establish a complete expanded LEARN/editor implementation.
Stock initialization at $E582, the insertion boundary check at $E2DE–$E2EA,
the backward-cursor beginning check at $E555, display/step numbering, and other
editing paths still encode the stock layout. Simply installing RAM does not
increase the stock capacity automatically, and changing one pointer once
will not survive every stock initialization path.

An 8 KiB RAM at $C000–$DFFF is a plausible custom-storage design if that window
is electrically available. A cartridge could manage it itself or modify the
stock storage paths. The stock boot scanner would still need a discoverable
header below $C000 to launch the cartridge software. There is no demonstrated
requirement that BIGSPACEB select the RAM: external decoding from A0–A15 and
confirmed read/write controls is another possible implementation.

## What this says about BIGSPACEB

The owner's experiment pulling BIGSPACEB low did not appear to disable
internal decoding. This weakens the specific hypothesis that it is a simple
active-low internal-decoder-disable input under those conditions. It does not
establish direction, timing requirements, or every possible input function.

Two ideas remain plausible but unverified:

- An output selecting $C000–$DFFF (or some other expansion range).
- An input affecting ASIC decoding under conditions not met by that experiment.

An ASIC can generate a fixed address-select output without any software setup
or intentional stock access to its selected region. Similarly, an externally
strapped decode-control input need not have a firmware control mechanism.
The end of the cartridge scan at $B000 is a software boundary; it does not by
itself identify the electrical purpose of BIGSPACEB.

The earlier broad `$2000–$DFFF` select interpretation is therefore a hypothesis,
not a result. Establishing the net's input/output direction and capturing it
alongside known address cycles will discriminate these possibilities better
than firmware alone. The possible $DF00–$DF03 startup dummy reads may provide
an initial observation without creating a new cartridge test program.

## Reproducing the audit

[Audit tool](../tools/audit_expansion_accesses.py) takes the original mapped
ROM and supplied disassembly paths, plus `--output` for its JSON result.
[Verification report](expansion-access-verification.json) records the explicit
operand, indirect instructions, nine tune headers, boot comparison addresses,
and modeled expansion-RAM read/write traces. Original uploaded ROMs remain
unchanged; the redirected cursor and RAM contents exist only in the emulator.

### RAM audit correction

The later [RAM ownership audit](ram-ownership.md) corrects misaligned listing
labels in $E555–$E573. The earlier indirect inventory includes an apparent
`ORA ($C5,X)` at $E556, which is an artifact of treating an operand byte as
an instruction. It is not a real stock pointer use. The binary-redecoded
RAM report supersedes that inventory entry. This does not change the
$DFFE,Y comparison finding or the modeled expansion-cursor tests.
