# Cartridge expansion connector J400

J400 exposes a full 16-bit CPU address bus, an 8-bit CPU data bus, bus-control
signals, an NMI connection, reset, power, and a **separate speech-ROM bus**.
This is enough for program ROM, external RAM or peripherals, and additional
speech storage, subject to confirming the ASIC's external bus timing/decode.

The pin numbers below are transcribed from the supplied single-page
`Maxx_steele_schematic.pdf`, rendered at higher resolution to inspect the
connector. They are schematic terminal numbers, not a verified front/back
view of the physical connector. `B` denotes a bar/active-low signal as the
owner explains. The owner's subsequently recovered notes report F2 as a
stable 2 MHz output; its identification as CPU Φ2 is not established.
The blurred NMI label is consistent with the owner's reading of NMIB.

## Pin list

| Pin | Signal | Function / interpretation |
|---:|---|---|
| 1 | GND | Ground |
| 2 | A15 | CPU address |
| 3 | A14 | CPU address |
| 4 | A13 | CPU address |
| 5 | A12 | CPU address |
| 6 | A11 | CPU address |
| 7 | A7 | CPU address |
| 8 | A8 | CPU address |
| 9 | A6 | CPU address |
| 10 | A9 | CPU address |
| 11 | A5 | CPU address |
| 12 | WRB | CPU write-related control; distinct from WEB |
| 13 | A4 | CPU address |
| 14 | OEB | Output-enable/read-related control |
| 15 | A3 | CPU address |
| 16 | A10 | CPU address |
| 17 | A2 | CPU address |
| 18 | A1 | CPU address |
| 19 | D7 | CPU data |
| 20 | A0 | CPU address |
| 21 | D6 | CPU data |
| 22 | D0 | CPU data |
| 23 | D5 | CPU data |
| 24 | D1 | CPU data |
| 25 | D4 | CPU data |
| 26 | D2 | CPU data |
| 27 | AUDIO AMP | Analog audio net to amplifier; not a CPU data signal |
| 28 | D3 | CPU data |
| 29 | F2 | Stable 2 MHz clock reported by owner; relation to CPU phase unknown |
| 30 | SA0 | Speech address bus bit 0 |
| 31 | WEB | Separate write-enable-related control from ASIC |
| 32 | SA1 | Speech address bus bit 1 |
| 33 | BIGSPACEB | Unresolved active-low expansion control/select |
| 34 | SA2 | Speech address bus bit 2 |
| 35 | NMIB, tentative reading | Probable active-low CPU NMI input |
| 36 | SA3 | Speech address bus bit 3 |
| 37 | RESET SYSB | System-reset-like net; owner reports grounding has no visible effect, direction unresolved |
| 38 | CT | Speech-ROM control/timing net |
| 39 | VBAT | Battery supply net |
| 40 | DOUT | Serial speech-ROM data net |
| 41 | V5W (possibly VSW in scan) | Logic supply net; confirm spelling and voltage behavior |
| 42 | DREQ | Speech-ROM data request |
| 43 | GND | Ground |
| 44 | ASTRB | Speech address strobe |

The low-resolution scan is easy to misread: **F2 is pin 29**, while **pin 36
is SA3**. WRB/OEB are pins **12/14**; the speech DREQ/ASTRB pair occupies
**42/44**. All 44 terminal numbers are accounted for once in this transcription.
Board continuity should confirm it before a cartridge PCB is laid out.

## BIGSPACEB: expansion control/select hypothesis

The drawing connects BIGSPACEB directly from the custom NCR ASIC to J400
pin 33. It is separate from the ASIC's RAMB and ROMB signals used for the
built-in memory, and separate from the connector's OEB and write controls.
That topology and its name suggest an active-low **address-space
select for expansion memory/peripherals**, but the schematic does not prove
the ASIC terminal's input/output direction. The owner subsequently reports
that pulling it low did not appear to disable the internal decoder. See
[the $C000–$DFFF access audit](expansion-accesses.md) for competing hypotheses
and the absence of identified stock expansion-RAM support.

The recovered notes also report no apparent functional change when grounding
BIGSPACEB, suggesting an output; they report the same for RESET SYSB (J400
pin 37), with no activity observed on that reset-like net under the tested
conditions. Neither result proves direction or rules out state-dependent
functions. RESET SYSB is distinct from the schematic's RESET SWB input/net.

The leading candidate is the otherwise available `$2000–$DFFF` region,
consistent with the owner's memory map. However, neither the scan nor the
ROM establishes BIGSPACEB's truth table. In particular, it is unverified
whether it covers that entire range, includes other addresses, is qualified
by Φ2, or differs between reads and writes. It should not yet be treated as
an electrically verified `$2000–$DFFF` chip select.

The boot scanner examines `$2000`, `$3000`, …, `$B000`, searching for a
signature and entry pointer. That proves software discovery behavior, not
BIGSPACEB decoding, and does not restrict expansion memory to those ten
locations. `$C000–$DFFF` is outside the stock discovery scan.

A cartridge with several devices would ordinarily combine the expansion
select with further address decoding. A small ROM also needs a defined
mapping: simply connecting low address bits under a broad select could mirror
its header across multiple scan locations. The supplied demo has absolute
addresses for `$A000–$AFFF`; detecting its header somewhere else does not
relocate its code or data. See [Cartridge discovery](memory-map.md#cartridge-discovery-and-header).

## F2: reported stable 2 MHz clock

Pin 29 connects to the ASIC terminal labeled F2. The owner's recovered
experimental notes identify it as a **stable 2 MHz clock**, and suggest the
name denotes frequency, consistent with other frequency-labeled ASIC outputs.
This supersedes the earlier assumption that the label meant Φ2.

A stable 2 MHz waveform could still be synchronous with the processor, but
frequency alone does not establish CPU cycle frequency, phase, valid-data
intervals, or write timing. Its intended use and behavior during sleep remain
unresolved. Do not use F2 as a cartridge write qualifier without correlating
it with actual read/write cycles.

## Pin 35: probable NMIB and a usable firmware hook

The faint connector label and the corresponding ASIC terminal are consistent
with **NMIB**, as the owner proposes. It appears to be a CPU interrupt
connection, rather than another address decode or ordinary GPIO. On a standard
6502 core NMI is triggered by a falling edge; confirm the custom core and net's
electrical implementation before designing the cartridge driver.

The original ROM gives unusually clear software support for this signal:

```text
$FFFA/$FFFB = $E011      hardware NMI vector
$E011: JMP ($0076)       writable handler pointer
$0076/$0077 = $E014      initialized on every reset
$E014: PHA
       LDA #$00
       STA $1E00
       PLA
       RTI
```

A cartridge can replace $0076/$0077 with its own handler address and finish
with `RTI`. The handler must preserve the registers it changes. `SEI` does not
mask a conventional 6502 NMI, so updating the two-byte pointer while an NMI
source can fire needs explicit coordination. Reset restores the stock pointer.

The stock handler's `$1E00` write is observed, but its hardware effect is
unresolved; it may acknowledge or control an ASIC interrupt source. It is
not proof of a cartridge NMI acknowledge register. The owner reports that
grounding the tentative NMI line caused no visible response. The short stock
handler makes that inconclusive: it preserves A and returns after this write.
A cartridge-installed counter or UART-reporting handler would test delivery
more directly, using a defined edge and confirmed electrical interface. There is no stock cartridge
interrupt dispatcher here. The normal IRQ vector is instead `$FDC5`, through
RAM $0078/$0079, and no separate IRQ terminal is identified on J400.

[NMI and boot verification](cartridge-port-verification.json) executes the
original NMI path and confirms the return restores A/X/Y and stack position.
It also executes the stock probe with the original demo mapped at $A000 and
confirms dispatch to $A013. These checks establish firmware behavior, not the
physical identity or electrical direction of pin 35.

## Read and write controls

OEB, WRB, and WEB are three distinct nets in the drawing. The two write-related
names should not be silently collapsed into one signal or assumed to have
identical pulse widths. Plausible roles include an unqualified write state
and a clock-qualified write strobe, but their exact relationship is unverified.
No CPU routine can establish their external timing: the ASIC generates it.

The recovered notes report substantial WEB activity and propose that it may
mark valid external bus cycles. This is a hypothesis, not a measured truth
table. If WEB is an ordinary active-low write enable, low would ordinarily
qualify a CPU write to an external device; high would merely mean that write
enable is inactive, not necessarily that a CPU fetch is occurring. If it is
instead a bus-valid or clock signal, that conventional interpretation may not
apply. External chips drive the CPU data bus on qualified reads; the CPU drives
it on writes. Capture WEB alongside WRB, OEB, address, and data to distinguish
these cases rather than infer direction from signal activity alone.

A logic-analyzer capture of a CPU read and write to cartridge space, alongside
F2 and BIGSPACEB, should show which net enables ROM output and which safely
strobes RAM or a peripheral. For a cartridge input/output design, address
selection and proper read/write qualification are both needed; an address-space
select alone is insufficient.

## Speech expansion signals

SA0–SA3 are separate from CPU A0–A15. The schematic connects them to the
LC8100's A0–A3 speech interface and LC3100 speech ROM address inputs.
ASTRB, DREQ, DOUT, and CT likewise connect the speech chip/ROM interface to
J400. The existing LC3100 DOUT goes to the LC8100's DIN and to cartridge DOUT;
an expansion speech device must obey the shared bus's selection/drive rules.
AUDIO AMP is a separate analog connection.

These nets provide the interface for additional speech storage. They do not
make speech ROM CPU-addressable through BIGSPACEB. The detailed LC3100 timing,
chip identification, and multi-ROM bus-sharing rules still need the full
manufacturer interface documentation or captures. See [Speech expansion](speech-interface.md#cartridge-speech-expansion).

## Measurements that will settle the open signals

1. Confirm connector orientation and continuity for pins 29, 33, 35, and the
   WRB/WEB/OEB group to the ASIC nets.
2. Capture F2, BIGSPACEB, OEB, WRB, WEB, and A13–A15 during reads and writes
   near `$0800`, `$1000`, `$2000`, `$BFFF`, `$C000`, `$DFFF`, and `$E000`.
   This distinguishes expansion decode boundaries and clock qualification.
3. Check whether F2 and pin-41 power remain present during sleep and wake.
4. Confirm pin 35's inactive level and existing drivers, then test a controlled
   NMI edge with a cartridge-installed handler. Establish the effect of
   `$1E00` before replacing the stock acknowledge behavior.

Confidence: high for the ROM vectors/discovery behavior and the clearly
readable pin assignments; moderate for NMIB identification; F2=2 MHz is an owner-reported measurement,
while its CPU phase relationship is unverified. Tentative for BIGSPACEB's purpose, with its
direction, exact decode, bus timing, and electrical details unverified.

## Recovered experimental notes

The owner supplied these observations in conversation after the initial pin
audit. They are recorded as reported experiments; original traces, instrument
settings, and test conditions are not available here. They revise hypotheses
but do not override verified ROM behavior. See [hardware observations](cartridge-hardware-observations.md).
