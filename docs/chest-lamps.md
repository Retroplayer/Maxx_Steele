# Chest lamps and GPIO reuse

The owner reports cuttable trace jumpers intended to disconnect lamp circuits
and reuse the ASIC pins. Their physical locations and the ASIC's direction
configuration are not established by the supplied ROM or schematic. No traces
have been cut and no original ROM image has been modified in this investigation.

## Hardware distinction

The schematic shows four body lamps, DS600–DS603, connected through J600
positions 4–7 and transistor drivers Q600–Q603 with base resistors R600–R603.
The ASIC nets are labeled **LAMP0, LAMP1, LAMP2, and HEADLAMP**. Thus there are
three explicitly numbered lamp channels and a separately controlled lamp;
these should not be assumed to be four interchangeable bits of one port.

The transistor stage separates the logic-side ASIC pin from the lamp-side
VBAT circuit. GPIO connections must use the isolated logic side of a jumper,
not a bulb/collector node. Whether the ASIC pin is configurable as input still
requires evidence; disconnecting a load does not change an output's direction.

## Three interfering $1600 writers

The disassembly and binary identify these three direct `STA $1600` instructions:

| CPU address | Context | Written value |
|---|---|---|
| $F4BF | Speech busy handler | Current pseudo-random byte in $5C |
| $F4D3 | End of phrase/direct sound | $00 |
| $F21D | Music note programming | Raw note value in A, before frequency conversion |

The speech and music writes support identifying $1600 as the numbered-lamp
output port. A low-three-bit correspondence to LAMP0–LAMP2 is likely but has
not been confirmed by walking-bit hardware tests. Whole-byte values in the
CPU traces do not prove all eight register bits are physical GPIO outputs.

**Removing only the speech randomizer would be insufficient.** End-of-speech
clearing and music-note updates could still change an assigned trigger output.
Initialization, alias decoding, and any future added code must also respect
the new port owner. This is a list of identified direct writes, not a proof
that no indirect or mirrored access could ever reach the port.

### Speech blinking

IRQ task 7 enters $F483. A low speech-ready/busy input at $1200 bit 7 branches
to $F4B5. That path decrements $5D. When it reaches zero it resets the divider
to $10, writes $5C to $1600, then evolves $5C:

```text
feedback = 1 XOR old_bit5 XOR old_bit6
next = ((old << 1) & $FF) | feedback
```

This is deterministic shift-register feedback, not a random-number source.
The first values from a zero seed are:

```text
00 01 03 07 0F 1F 3F 7E FD FB F7 EF DF BE ...
```

Following the first update, the divider produces one write per 16 busy-handler
visits. Those visits are conditional on speech status; they are not an
unconditional background timer. If $5D begins at zero, the first decrement
wraps to $FF, delaying the first update until the 256th busy visit. This was
verified in execution, rather than assuming an immediate first update.

The busy path also clears launch latch $57. The completion path clears speech
state $5B after writing zero to the lamps. These operations must remain intact
when disabling blinking so words and phrases continue advancing correctly.

### Music-linked lamps

$F21C begins `TAY; STA $1600`, then computes a note frequency and writes the
sound-generator registers at $1C00. Therefore its first port write is an
additional lamp animation source. It is not the frequency-generator write
itself. Silencing the $1600 store can leave the subsequent sound writes intact.

### Separate headlamp control

The headlamp command path sets RAM $71 to $00 or $40 at $EBCA/$EBCE/$EBD0.
IRQ task 5 at $EED0 uses that state and divider $72 to write $1000 at $EEE2,
including an XOR with $82. This is a separate lamp-related output path from
the $1600 speech/music writes. Its physical PWM/gating details remain unmeasured.
Do not alter it if only the three speech/music lamp channels are being reused.

## Concrete no-blink patch candidates

If the numbered-lamp output port is to be dedicated to new hardware, a minimal
candidate is to suppress all three identified $1600 stores:

| CPU address | Raw 8 KiB payload offset | Original | No-write candidate |
|---|---|---|---|
| $F21D | $121D | `8D 00 16` | `EA EA EA` |
| $F4BF | $14BF | `8D 00 16` | `EA EA EA` |
| $F4D3 | $14D3 | `8D 00 16` | `EA EA EA` |

For the 64 KiB mapped image, file offsets equal the CPU addresses. Programmer
images with displaced firmware require their own offset translation. Verify
the exact ROM hash and original bytes before any actual patch.

These substitutions were applied **only to temporary emulator copies**.
Three NOPs occupy the same bytes and nominal six cycles as the original
absolute STA on a standard 6502, preserving instruction layout and status
flags. Physical ASIC bus timing has not been tested.

The model checks demonstrate:

- All 256 speech seeds retain identical feedback, divider, latch, and RAM state
  while the $1600 write disappears.
- 75 music cases (three channels, note values 0–24) retain identical $1C00
  writes, scratch RAM, and final registers/flags.
- Phrase and direct-sound completion still clear $5B without forcing the
  GPIO port low.

This is a proposed removal of stock writers, not a complete sonar firmware
patch. Custom code must establish a defined idle output at startup, including
wake paths, and become the sole owner of the reserved bits. If some lamps are
retained, use a common output helper and software shadow to merge them with
reserved GPIO bits, preserving calling conventions and interrupt safety.
Do not reconstruct output state from a port read without confirming readback
semantics: $1600 already reads unrelated alarm/battery inputs.

## Sonar trigger and return feasibility

One disconnected lamp output is a plausible **trigger** resource once its
register bit, polarity, and electrical limits are measured. Receiving the
sonar return is a separate question: no direction register or input capability
for these lamp pins has been identified. Do not connect a sonar output to an
ASIC output simply because its lamp jumper was cut.

Two routes remain possible:

1. Confirm a lamp pin's supported input configuration and read bit, then use
   it for the sonar return.
2. Keep a lamp pin for trigger and use a proven spare input or an added
   cartridge input latch/timer for the return.

$1600 input bit 6 participates in alarm detection at $EE36 and input bit 7 in
battery monitoring at $EEA2. They are not demonstrated spare sonar inputs.
Preserve those functions unless deliberately redesigning them.

Identify the exact Polaroid module before writing the driver. Its INIT/ECHO
requirements, blanking interval, output electrical behavior, and whether the
return is a latched arrival indication must come from that module's interface.
Do not assume an HC-SR04-style pulse-width protocol. Range timing also needs
a measured timebase; existing IRQ polling may be too coarse for the desired
resolution. Trigger-to-return timing, timeout handling, and interrupt load
must be designed together.

## Next hardware checks

- Locate the jumpers and confirm continuity from each ASIC net to its driver.
- Determine whether the cut disconnects only the driver or any other load.
- Use controlled walking-bit writes to establish lamp/register correspondence,
  with the three stock writers suppressed in a reviewed test ROM.
- Establish supported GPIO direction/readback from NCR documentation or careful
  hardware evidence before planning a return connection.
- Measure logic levels and the module interface, then choose polling, timer,
  or cartridge-latch timing appropriate to the range resolution.

## Reproduce the investigation

```sh
cd /workspace/Maxx_Steele
/workspace/.venvs/maxx-steele/bin/python tools/analyze_chest_lamps.py \
  --rom /path/to/Maxx_Steele_Main_Mapped.bin \
  --report /tmp/chest-lamps-verification.json
```

The tool verifies the known original ROM and records emulator-only patch
comparisons. See [the saved report](chest-lamps-verification.json). No speech
payload, external speech-ROM design, or cartridge template was changed.
