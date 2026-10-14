# NCR/CBS ASIC U300: schematic pin inventory

The schematic does **not show sixteen spare GPIO pins** corresponding to the
unused $1800/$1A00 selections. It depicts approximately the entire reported
68-pin package: the inventory contains **67 drawn terminal entries**, assigned
to buses, peripherals, clocks, supplies, and control functions.

That is a count of terminal appearances in the drawing, not a fully verified
set of 67 distinct physical pin numbers. Several numerals are blurred or have
conflicting possible readings. Therefore this audit does not identify the one
remaining package pin as a confirmed NC, or certify a board-ready pinout.
It does strongly weaken the idea that two visibly unconnected eight-pin ports
are waiting to be used.

## Identification and evidence

The owner reports a **68-pin PLCC**, marked **NCR 609-0380087** and **CBS**, and
suggests a custom design based on the NCR 6500/1. The schematic labels U300
simply as CPU. The package/marking report and the existing 6502 firmware are
consistent with a custom 6502-based controller, but do not identify its exact
base silicon or demonstrate 6500/1 pin/register compatibility.

No manufacturer specification for this exact part has been obtained. Do not
apply a generic 6500/1 pinout to U300 on that basis. The ROM depends on external
RAM and program ROM and uses application-specific functions in the $1000
region; these are the verified properties relevant to cartridge design.

Sources are the owner's report and the supplied `Maxx_steele_schematic.pdf`.
The scan was rendered to 8000×5177 pixels for inspection. Enlarging a scan
makes terminal tracing easier but cannot restore illegible original lettering.

## Where the terminals go

| Group | Drawn terminal entries | Signals / destinations |
|---|---:|---|
| CPU address bus | 16 | A0–A15, RAM/ROM and J400 |
| CPU data bus | 8 | D0–D7, RAM/ROM and J400 |
| CPU bus/reset controls | 9 | WRB, RAMB, OEB, ROMB, BIGSPACEB, WEB, NMIB-like net, F2, RESET SYSB |
| Head and sensor signals near top of symbol | 7 | Alarm/data-clock-like label, F24HZ-like clock, ALARMB, F4MHZ-like clock, POWERB, RESET SWB, PHOTOCELL |
| Body and power control | 6 | LAMP0–LAMP2, HEADLAMP, RADIOIN, POWER ENABLE B |
| Supply and crystal | 4 | VDD, VSS, XTAL0, XTAL1 |
| Audio | 1 | AUDIOUT through R402 |
| Motor COP link | 4 | COP clock, motor data out, motor done, master clock |
| Speech interface | 8 | Speech Start/busy, C0–C4, timing net to LC8100 pin 27 |
| Additional COP/control signals near bottom | 4 | COP clock-like net, data-clock-like net, COPDATA, RC/diode control network |
| **Total** | **67** | Functional connections drawn, with uncertain labels/numerals retained |

The separate top/bottom clock-like signals should not be collapsed into one
net just because their blurred text looks similar. Their drawn wires have
separate terminal appearances. Functional directions are not established by
an inventory of labels alone.

[Full CSV inventory](asic-pin-inventory.csv) records individual signals and
pin-number readings, explicitly marking ambiguity. Examples with clear
readings include VSS=1, VDD=35, XTAL0=55, XTAL1=56, AUDIOUT=10,
LAMP0/1/2=26/27/28, motor COP terminals=50/51/52, and speech C0–C4=38–42.
Some earlier casual ASIC pin-number readings should therefore remain tentative;
J400 connector numbers are a separate numbering system.

The cropped source views preserve the relevant drawing for review:
[upper terminals](asic-schematic/upper.png),
[bus terminals](asic-schematic/bus.png), and
[lower terminals](asic-schematic/lower.png).

## What the decoder spacing implies

The owner's 74HC138 analogy is reasonable: within $1000–$1FFF, A9–A11 can
select eight $200 windows using a three-to-eight decode. This would account
for the regularly spaced software addresses. It is a plausible **logical
structure**, not evidence that the ASIC literally contains a 74HC138 circuit
or ignores every lower address bit.

Nor does each selection imply an eight-bit external port. The observed
functions include serial interfaces, mixed status/output functions, sound
programming, and system control. An unused selection could expose internal
state, configuration, a test function, unbonded signals, or no function at all.
Extra GPIO could also share/multiplex existing pins rather than require sixteen
new physical terminals. None of those possibilities is established yet.

## Consequences for expansion

Do not reserve a sixteen-pin ASIC GPIO resource in the cartridge design.
The UART and optional cartridge VIA/PIA remain independent hardware choices.
$1800 and $1A00 are still candidate I/O bases needing decode validation;
the package inventory cannot establish whether the ASIC responds there.

To complete a physical pinout, inspect the board/package orientation and
trace the ambiguous terminal numbers, rather than filling gaps by subtraction.
Board evidence is also needed to distinguish unused, supply, test, or shared
pins. No connected or unshown terminal has been tested as a spare GPIO here.

## Recovered clock/control observations

The owner subsequently reports F2 as a stable 2 MHz clock, plausibly named
for frequency rather than CPU phase. Grounding RESET SYSB and BIGSPACEB
produced no apparent effect; WEB showed substantial activity. These are
[reported hardware observations](cartridge-hardware-observations.md),
not verified ASIC direction or bus-timing specifications.
