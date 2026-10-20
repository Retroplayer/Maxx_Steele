# A0 review status

Checked with KiCad 9.0.2 on 2026-10-20.

| Check | Result |
|---|---|
| Schematic ERC | 0 violations |
| PCB DRC | 0 violations |
| Unconnected PCB items | 0 |
| Schematic/PCB parity | 0 mismatches |
| Independent connector mapping | 44 unique contacts; 29 used, 15 isolated |
| Retained core topology | Matches upstream after removing C64 reset driver |
| Retained component positions | Match upstream within 2 micrometres of import rounding |
| Copper layers | 4; F.Cu / In1.Cu / In2.Cu / B.Cu |

The independent check compares schematic net membership with the source XML,
then checks every PCB pad and the connector faces/pitch. Reports are included.
No DRC exclusions are used. U1 has an explicit edge-finger clearance rule;
ordinary copper has 0.25 mm minimum board-edge clearance. Signal tracks and
net clearance are 0.20 mm minimum; new vias are 0.60/0.30 mm.

Original fine-pitch and SDIO routing was retained or restored, and host bus
routing was edited and rerouted. Inner ground fills and outer ground fills
have been regenerated. Previews show bare boards because component 3D models
are not bundled. BOM.csv lists the electrical schematic components; U1 is
part of the PCB itself. The open-hardware logo is a board-only graphic.

## Required before fabrication / powered testing

- Confirm physical connector insertion orientation and tongue fit against Maxx.
- Review the STM32F405 exact pin specifications, 3.3 V high-level margins at
  the Maxx ASIC, and power-off tolerance when VSW turns off during sleep.
- Measure WRB/OEB timing and validate a Maxx-specific firmware implementation.
- Specify the fabricator's four-layer stackup, plated finger finish and bevel.
- Review USB/cartridge power isolation; J1 must remain open when robot-powered.

This is an electrically untested CAD prototype. Clean ERC/DRC does not prove
bus timing, voltage compatibility, cartridge fit, or working RAM/ROM emulation.
No Maxx STM32 firmware port is included. Original KFF firmware is unsuitable.
