# Kung Fu Maxx — KiCad conversion, revision A0

A Maxx Steele cartridge PCB derived from Kim Jørgensen's original
STM32F405-based **Kung Fu Flash**. This is an edited schematic and routed-PCB
prototype, not a tested cartridge or a firmware release.

**A0 uses four copper layers:** F.Cu, In1.Cu ground plane, In2.Cu bus
crossovers with ground fill, and B.Cu. Board thickness is 1.6 mm; the final
fabricator stackup remains to be specified.

Open **KungFuMaxx.kicad_pro** in **KiCad 9**. The schematic, board, symbols, and
footprints are supplied locally; no custom libraries need downloading.

## Changes from Kung Fu Flash

- Replaced the C64 edge connector with **44 uniquely numbered Maxx contacts**.
- Connected all 16 address lines to STM32 PB0–PB15, retaining the fast port layout.
- Connected D0–D7 through the original eight 100-ohm series resistors to PC0–PC7.
- Connected **J400 pin 12 WRB to PA0** and **pin 14 OEB to PA8**.
- Connected switched **5 V at pin 41** to the regulator; ground is pins 1 and 43.
- Left battery voltage **pin 39 isolated**, along with the speech bus and other
  unresolved expansion signals. The tentative NMI pin is also disconnected in A0.
- Removed the C64 host-reset driver Q1/R3/R4 and disconnected C64-only controls.
- Retained the MCU support circuitry, USB, SDIO/microSD, programming header,
  regulator, three buttons, and LED at their original positions.
- Rerouted the host bus; retained original fine-pitch escape routing where useful.
- Added two inner layers to finish address-bus crossovers while preserving the
  existing outer-layer circuitry.
- Corrected the original SD footprint courtyard and off-board silkscreen.
- Extended the upper USB-side outline **1.375 mm** to clear its mounting-pad
  copper. The cartridge tongue, 2.54 mm pitch, and original 1.6 mm thickness remain.
- Added A0 prototype markings and retained upstream attribution/license.

The original source files are preserved unchanged in `upstream/`, including
its XML netlist. Original project: https://github.com/KimJorgensen/KungFuFlash
at commit `7121a018c8608feafc2180d910ce58acddbec5e3`. Development moved to
https://codeberg.org/KimJorgensen/KungFuFlash . This is an altered derivative,
not a release by the Kung Fu Flash author. See `LICENSE.upstream`.

## Connector orientation — review before fabrication

The new footprint uses **even contacts 2–44 left-to-right on F.Cu**, viewed from
the component side with the fingers pointing down. The corresponding B.Cu
positions are odd contacts 1–43; viewing the back directly mirrors their order.
See `PINOUT.md` and `pin-map.json`.

This is an explicit physical convention, not a verified insertion drawing.
Confirm it against the actual Maxx slot and the owner's outside-looking-in
connector drawing before ordering boards. The two ground contacts alone do not
prove end-for-end orientation. Do not use ordinary C64 signal numbering.

The owner's v2 connector PDF swaps WRB/OEB. **Use the owner's later correction:
12=WRB and 14=OEB**, as implemented here.

## Electrical and firmware limits

The hardware follows KFF's direct STM32 bus approach, with **3.3 V output-high
levels** and no dedicated level-translator ICs. The 100-ohm resistors are not
level translators. Verify the exact STM32's pin tolerance and Maxx's data-input
thresholds, including power sequencing. Do not apply this wiring directly to
the RP2350 board; it is a different MCU/interface.

WRB is the owner-confirmed RAM write strobe. OEB's timing, data-valid intervals,
and bus release requirements still need measurement. F2, WEB, BIGSPACEB, and
RESET SYSB are deliberately not used to guess a CPU-phase or select signal.

**A Maxx-specific STM32 firmware port is still required. Do not install the
stock C64 KFF firmware as a Maxx implementation.** The stock C64 launcher and
PHI2-synchronized handler are incompatible. This PCB conversion does not itself
provide RAM/ROM emulation. The proposed first firmware test serves a small
cartridge ROM at $A000, followed by RAM and USB/SD mailbox services.

Power is from **VSW**, so the board and its volatile emulated RAM lose power
when that rail switches off. Retention requires a separate solution. The Maxx
CPU/RAM can remain powered during sleep while VSW is off: powered-off STM32
pin behavior and possible back-powering must be checked before connection. Leave
**J1 open** when robot-powered: it directly joins USB VBUS to the cartridge
5 V rail when fitted, rather than providing automatic power-source isolation.

## Checks and previews

The current machine-readable results are in `reports/`; `CHECKS.md` records
what passed and what remains unverified. No rule violations are hidden with
DRC exclusions. The one explicit custom rule permits the plated edge fingers
of U1 to approach the routed board edge; ordinary copper retains edge clearance.

- `previews/KungFuMaxx-schematic.pdf`: schematic.
- `previews/`: front/back layout and unpopulated-board previews.
- `reports/schematic-netlist.xml`: netlist exported from the native schematic.
- `reports/connectivity-verification.json`: independent core/pinout checks.
- `upstream/`: the unchanged design used as a reference.

To repeat the checks on Linux with KiCad 9 and its pcbnew Python module:

```sh
tools/kicad.sh sch export netlist --format kicadxml \
  -o reports/schematic-netlist.xml KungFuMaxx.kicad_sch
tools/kicad.sh sch erc --format json --exit-code-violations \
  -o reports/erc.json KungFuMaxx.kicad_sch
tools/kicad.sh pcb drc --format json --schematic-parity --exit-code-violations \
  -o reports/drc.json KungFuMaxx.kicad_pcb
/usr/bin/python3 tools/verify_design.py
```

KiCad's own GUI ERC/DRC dialogs provide the corresponding checks on Windows.
A clean CAD check establishes connectivity/clearance under the stated rules;
it does not establish ASIC voltage margins, bus timing, physical fit, or firmware
operation. Edge finish/bevel and manufacturing details need review with the PCB
supplier after the connector orientation has been confirmed.
