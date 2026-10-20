# Maxx Steele reverse engineering

Firmware and peripheral research for the 1984 Ideal/CBS Toys robot.

- [Pico USB remote emulator: installation and usage](pico/README.md)
- [ROM- and capture-verified remote protocol](docs/remote-protocol.md)
- [Motor COP commands, counters, positions, and stalls](docs/motor-control.md)
- [Cartridge connector pinout, BIGSPACEB, F2, and NMI](docs/cartridge-port.md)
- [I/O register sweep: reads, writes, widths, and decode gaps](docs/io-registers.md)
- [NCR/CBS ASIC pin inventory and unused-port hypothesis](docs/asic-pins.md)
- [RAM ownership, complete zero-page map, and cartridge API constraints](docs/ram-ownership.md)
- [WinCUPL cartridge decoder, pinout, and R/W output](hardware/decoder/README.md)
- [All head messages and proposed 1602 LCD text](docs/head-messages.md)
- [Byte-identical KickAssembler main-ROM source and build](asm/README.md)
- [Memory map](docs/memory-map.md)
- [Head display segment encoding and serial communication](docs/head-display.md)
- [Chest lamps, interfering port writers, and sonar GPIO feasibility](docs/chest-lamps.md)
- [Speech ports, vocabulary, phrases, and expansion research](docs/speech-interface.md)
- [Fixed-layout cartridge format](docs/cartridge-builder-format.md)
- [Original demo cartridge](docs/demo-cartridge.md)

The Pico implementation uses MicroPython PIO for precise waveform generation
and a USB CDC text-command interface. A Windows-compatible Python console is
provided in `pc/remote_cli.py`. Host tests validate generated waveforms against
the original robot ROM. Physical Pico operation and the transmitter-jack
electrical interface still require measurement and testing.

Original uploaded ROM images and captures are kept outside the checkout in
the workspace attachments; the tools accept their paths and verify the mapped
ROM's hash. No cartridge template has been modified.

A complete ZIP containing the source, documentation, and verified ROM image
is available at [dist/Maxx_Steele_project.zip](dist/Maxx_Steele_project.zip).
