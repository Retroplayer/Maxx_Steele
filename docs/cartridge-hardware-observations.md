# Recovered cartridge-port experiments

Source: experimental notes supplied by the owner in conversation. No original
captures, instrument settings, or complete test conditions accompany them.
Separate observations from the interpretations below.

| Signal / J400 pin | Reported observation | Interpretation and current limit |
|---|---|---|
| F2 / 29 | Stable 2 MHz clock | Frequency-labeled output is plausible; CPU phase/timing relationship unknown |
| RESET SYSB / 37 | No activity observed; grounding caused no apparent effect | Output is suspected, but direction and behavior during reset/sleep are unverified |
| BIGSPACEB / 33 | Grounding caused no apparent effect | Output is suspected; internal-decoder-disable input hypothesis weakened; decode remains unknown |
| Tentative NMIB / 35 | No visible effect when grounded | Inconclusive with stock handler; test using a cartridge-installed handler |
| WEB / 31 | Substantial activity | Could be write enable or another bus qualifier; polarity and cycle meaning require correlated captures |

These observations supersede the prior assumption F2=Φ2. They do not establish
that WEB is Φ2, that F2 equals the CPU instruction-cycle clock, or that high WEB
means a fetch. A conventional active-low write enable is asserted low for a
write; its inactive state alone does not identify reads versus internal work.

The notes describe NMI as effectively returning without a visible action.
The binary is more precise: it dispatches through RAM $76/$77 to $E014,
saves A, writes $00 to $1E00, restores A, and executes RTI. The write may have
an internal control/acknowledge effect even if no visible behavior changes.

For cartridge design, keep F2, WEB, WRB, and OEB as separate signals until
measured together. Device-to-CPU data transfer occurs on reads; CPU-to-device
transfer occurs on writes. Address decode and appropriate transfer direction
must both qualify a cartridge device's output or write strobe.

A useful next measurement is a short cartridge test that deliberately reads
and writes known external addresses while a logic analyzer records F2, WEB,
WRB, OEB, and address/data. A separate installed NMI handler can increment an
expansion-RAM counter, giving an observable interrupt result. No such hardware
measurement or cartridge ROM change has been performed in this update.
