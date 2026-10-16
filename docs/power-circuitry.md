# Maxx power circuitry: schematic and firmware pass

Source: owner's `Maxx_steele_schematic.pdf`, one scanned sheet dated 7/31/84,
plus byte-verified stock assembly. This is a schematic interpretation; no rail,
current, reset, or timing measurements have been performed. Blurred part labels
are not treated as definitive identifications.

## Supply domains

| Net | Source | Connections visibly established |
|---|---|---|
| VBAT | Battery, fuse F100 (5 A), master switch path | U101 input, motor-driver supply, audio-amplifier supply, head connector, cartridge pin 39 |
| VC | U101 7805 output | CPU U300 VDD, RAM U400 VCC, head connector; upstream of logic power switch |
| VSW | Q100 high-side switch from VC | Main ROM U401 supply, receiver supply, cartridge pin 41; additional switched peripherals require tracing individually |

VC is continuous **while the master battery switch is on**, not independent of
that switch or immune to battery removal. No separate RAM backup battery or
automatic backup-source selector is shown in this circuit. RAM retention during
sleep is supplied by keeping VC present. The head also receives VBAT.

The schematic battery annotation appears to read **8 V / 5 Ah**; previously
reviewed owner/manual/collector references describe **10 V** packs. This source
discrepancy must not be resolved by choosing a charger voltage from the scan.
Identify the actual installed battery and board before modifying charging.

## Logic switching

U101 provides regulated VC. Q100, marked TIP42, is a PNP high-side switch
between VC and VSW. R111 (1 kOhm) returns its base to VC; R103 (390 Ohm) connects
the base to Q101's collector-side driver path. Q101's emitter is grounded and
its base is fed through R104 (1.2 kOhm), with R110 (10 kOhm) to VC. The precise
Q101 type marking is not clear enough to rely on; the drawn topology is a
low-side base driver for Q100.

The control path leads to the ASIC's POWER ENABLE B net. This is separate from
the head's POWERB signal into the ASIC. Consequently a head replacement must
not assume its POWERB pin directly switches Q100, or connect it blindly to the
prototype's generic main-power output. The ASIC participates in system power
control; its truth table remains to be measured.

Q100 switching VSW does not disconnect VBAT from the motors or amplifier.
Motor-control electronics being disabled is distinct from physically removing
motor battery power.

## Sleep sequence and what it implies

Stock ROM:

```text
$EE78  SEI
$EE79  LDA #$02
$EE7B  STA $1E00
$EE7E  LDA #$E5
$EE80  JSR $ED4F       ; send head command
$EE83  JMP $EE83
```

Reset writes $00 to $1E00 at $E044. The default NMI handler also writes $00
at $E017. These prove control-register activity, not the hardware meaning of
every bit.

The CPU and RAM staying powered is consistent with retention. However, because
the **main ROM is supplied by VSW**, the infinite loop does not prove the CPU
continues fetching indefinitely after VSW is removed. Clock inhibition,
internal suspend, or another ASIC mechanism could intervene. Correlate $1E00
effects, POWER ENABLE B, VSW, and bus activity before specifying replacement
sleep/wake behavior. Wake may involve reset, rather than resuming at $EE83.

## Low-battery detection

U102 is an LM358 half, powered from VBAT. The scan shows its inverting input
referenced to VC, and its noninverting input fed from VBAT through R105
(apparently 9.1 kOhm), with R106 (10 kOhm) to ground. C105 (0.1 uF) connects the
output to the divider node and affects transitions; this is not a precision
supervisor with a specified reset delay. R108 and CR106 provide output
resistance/clamping toward the VC domain.

If those readings are correct and VC=5.0 V, the nominal crossing is:

`VBAT = 5.0 * (9.1 + 10) / 10 = 9.55 V`.

That is a conditional calculation, not a measured trip voltage. Comparator
offset, regulator behavior, component tolerances, and the actual resistor value
matter. The circuit supplies a battery-status indication, not an established
hardware battery-disconnect threshold.

The ROM polls $1600 bit 7 at $EEA2. A high indication reloads $96 to $FF; a low
indication permits the state to count down on timer phases. At zero the
foreground path selects phrase $1A and re-arms the state. This establishes
software qualification and warning behavior, not a hard undervoltage cutoff.

## Charging path

The lower-left block has transformer T100, the charging connector assembly
J100/J101, rectifiers CR101/CR102, filter C100 (100 uF / 25 V), regulator U100
with heatsink H100, and isolation/protection diodes CR104/CR105 toward the
battery/switch path. U100's type and the complete setting network require board
identification before calculating charge voltage/current or replacing it. Do
not assume the external transformer is a regulated DC charger.

## Implications for the new hardware

- A head controller that must wake Maxx belongs on an always-available supply,
  using VC through its 3.3 V regulator if the available current allows it.
- The cartridge's existing 5 V pin is **VSW**, not VC. A Pico powered only there
  will turn off with that rail; its SRAM emulation will not retain data. A
  separate retained supply or nonvolatile save policy is necessary if retention
  is required. The Pico's PSRAM also loses data without power.
- A DS3231 coin cell backs up the RTC, not the RP2040 or original SRAM.
- FRAM can retain learned programs without maintaining RAM supply, but does
  not alone replace the power needed for the head's wake/reset functions.
- Replacing the 7805 with an efficient regulator can reduce loss on the retained
  rail. At 10 V input and 100 mA output, a 7805 dissipates approximately 0.5 W;
  this is an illustration, not measured robot consumption.
- A supervisor can add specified reset thresholds/delay and RAM write inhibit.
  Its target reset net must be established; do not treat the unresolved
  RESETSYSB cartridge signal as a proven reset input.

## Useful measurements on the removed motherboard

| Signal | On / sleep / wake observation needed |
|---|---|
| VBAT, VC, VSW | Actual levels, sequencing, and sleep current |
| ASIC POWER ENABLE B and Q101 base | Switching polarity and delay |
| Head POWERB, ALARMB, master-reset path | Direction, wake transition, reset timing |
| CPU bus / clocks | Whether execution stops before ROM power is removed |
| RAM CS#/WE# | Inactivity during sleep and transitions |
| $1600 battery-status input | Trip/recovery threshold under a controlled supply |

Cropped evidence: [regulator/switch](power-schematic/regulator.png),
[memory supplies](power-schematic/memory.png),
[charger](power-schematic/charger.png),
[head connections](power-schematic/head.png).
