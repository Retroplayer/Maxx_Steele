# Cartridge decoder

[maxx_decoder.pld](maxx_decoder.pld) implements the proposed map in WinCUPL
for a combinational **ATF22V10C**, using the generic `g22v10` device model.
This is a working device choice, not a finalized PCB/package decision.

| CPU range | Select | Allocation |
|---|---|---|
| $0000–$1FFF | None | Existing robot RAM and ASIC I/O |
| $2000–$9FFF | RAM_CS_N | 32 KiB cartridge SRAM |
| $A000–$BFFF | ROM_CS_N | 8 KiB cartridge ROM: BASIC then monitor |
| $C000–$DFFF | IO_CS_N | Cartridge I/O, requiring device subdecoding |
| $E000–$FFFF | None | Existing main ROM |

A12 does not affect these broad selects. The source exposes it as a reserved
input for future finer decoding. UART and VIA/PIA selection still needs low
address-bit decoding within the I/O window; do not connect every peripheral
to IO_CS_N and let them all respond at once.

## Inputs and unresolved bus signals

RD_N is assumed low only during a CPU read transfer and WR_N low only during
a CPU write transfer. **This polarity and mutual exclusion are requirements,
not conclusions about the robot's connector signals.** OEB and WEB are
candidate connections, pending measurements; WRB remains a separate signal
whose relationship to WEB must be established. Do not connect a presumed raw
R/W level or free-running clock to WR_N under this interface contract.

The equations deliberately use neither F2 nor BIGSPACEB. F2 is owner-reported
as a stable 2 MHz clock; it has not been verified as a write qualifier.
RESET SYSB and NMIB likewise do not control this decoder. ENABLE is a
cartridge-local active-high input, normally strapped high; it can disable all
address selects and transfer outputs for development.

## Outputs and combined R/W

All `_N` outputs are active low. RAM_CS_N, ROM_CS_N and IO_CS_N depend on
address and ENABLE, so they can remain selected between transfers. The OE/WE
and I/O strobes additionally require exactly one asserted transfer input.
With both transfer inputs high (idle) or both low (invalid), all OE/WE and
I/O strobes are inactive.

| RD_N | WR_N | Interpretation | RW | Transfer strobes |
|---:|---:|---|---:|---|
| 0 | 1 | Read | 1 | Selected read strobe active |
| 1 | 0 | Write | 0 | Selected write strobe active |
| 1 | 1 | Idle | 1 | Inactive |
| 0 | 0 | Invalid overlap | 1 | Inactive |

RW is a **qualified direction output**, high for reads/idle and low for valid
writes. BUS_ACTIVE_N is low only during a valid transfer to a selected
cartridge region. ENABLE gates BUS_ACTIVE_N and all selects/strobes, but RW
still reflects the transfer-input interpretation when the cartridge is disabled.
A ROM-region CPU write can assert BUS_ACTIVE_N/RW without producing ROM_OE_N
or any RAM/I/O write strobe; the ROM is not writable through this decoder.

This pair does not reproduce a raw 6502 R/W signal that is stable throughout
the address phase. A VIA/PIA may require that raw direction plus a properly
timed clock/enable. Do not assume BUS_ACTIVE_N can serve as its clock without
checking edge timing, setup/hold requirements, and the selected device.

## Pin assignment

| PLD pin | Signal | Direction |
|---:|---|---|
| 1 | A15 | Input |
| 2 | A14 | Input |
| 3 | A13 | Input |
| 4 | A12, reserved | Input |
| 5 | RD_N | Input |
| 6 | WR_N | Input |
| 7 | ENABLE | Input |
| 8–11, 13 | Unused; give defined input levels | Input |
| 12 | GND | Supply |
| 14 | BUS_ACTIVE_N | Output |
| 15 | RW | Output |
| 16 | IO_WR_N | Output |
| 17 | IO_RD_N | Output |
| 18 | ROM_OE_N | Output |
| 19 | RAM_WE_N | Output |
| 20 | RAM_OE_N | Output |
| 21 | IO_CS_N | Output |
| 22 | ROM_CS_N | Output |
| 23 | RAM_CS_N | Output |
| 24 | +5 V | Supply |

Use the actual package datasheet for PCB orientation and decoupling. The
logical model uses all ten output macrocells and no registered state.
Transfer equations reference the select outputs; include the fitted feedback
path in propagation-delay analysis.
Combinational address selects can change/glitch as address bits change;
safe memory writes rely on validated transfer strobes and timing margins,
not address decoding alone. Mutual-exclusion gating is not a glitch filter.

## Memory wiring and autorun

A 32 KiB SRAM can use CPU A0–A14 directly, with the provided CS/OE/WE outputs.
Every CPU address in the RAM window then maps to one unique SRAM location,
but physical offsets wrap: CPU $2000 maps to SRAM $2000, CPU $8000 to SRAM
$0000. If a linear offset from CPU $2000 is desired, extra remapping logic
would be needed; ordinary RAM use does not require that.

An 8 KiB ROM uses CPU A0–A12, ROM_CS_N and ROM_OE_N. If using
flash or EEPROM, hold its programming/write input inactive during normal use. CPU $A000 maps to image
offset $0000; $B000 maps to offset $1000. Put the monitor autorun header at
image offset $1000: `06 B0 28 63 29 20`, dispatching to CPU $B006. The actual
BASIC/monitor image is separate work; no ROM image is created here.

## Verification and compilation

Run from the repository root:

```sh
python tools/verify_decoder.py
```

The verifier parses the actual PLD Boolean equations and checks all 128
address-nibble/transfer/enable combinations against the intended map. It
checks idle/overlap suppression, direction, and mutual exclusion. Low address
bits are absent from the equations and therefore do not change these outputs.

WinCUPL and its fitter are not installed in this environment. **Compilation,
device fitting, JEDEC generation, and hardware timing remain unverified.**
In WinCUPL, compile the source against the installed 22V10-compatible device
library, inspect the pin/fitter report, then select ATF22V10C in the programmer.
No guessed JEDEC file is supplied. The Boolean check does not substitute for
compiler/fitter or electrical validation.
