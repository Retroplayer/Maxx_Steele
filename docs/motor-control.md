# Motor COP, counters, and main-CPU control

The motor COP abstracts motor driving and motion-count acquisition. The main
6502 nevertheless handles command selection, arm/wrist coupling, position
bookkeeping, waiting for completion, and a counter-based stall check. Replacing
the COP would require reproducing its replies as well as accepting commands.

Evidence: original mapped ROM (hash recorded in the verification report), the
supplied schematic, and execution of original 6502 routines using modeled COP
responses. The COP program itself has not been dumped. This documents the CPU
side of its interface; it does not establish the COP's internal algorithms.

## Hardware

The schematic identifies U500 as a COP420 and five motors: B500 claw,
B501 arms, B502 wrist, B503 left wheel, and B504 right wheel. Its switch labels
include arm front/back limits, wrist home/back positions, claw/arm/wrist count,
wheel counter, claw position, and claw open/close limits (S500–S510).
These support local feedback and limit handling. They do not establish
quadrature encoding. The CPU sees four count channels, including a shared
wheel channel; no separate left/right encoder queries have been identified.

## Serial interface

Motor transmit entry **$ED55** shares the head display serializer. It sends
bytes MSB first using $1200 bit 0 for outgoing data and bit 2 for motor clock
control. Each bit writes `$1C` or `$1D`, then `$F8`. Timing waits on $1000
bit 6. Actual timing, electrical polarity, and COP pin mapping require hardware
measurement; the ROM does not itself provide a measured baud rate.

Request/reply entry **$ED7B** first sends the request through $ED55, then clocks
in eight bits from **$1000 bit 0**, MSB first. Receive clock writes are `$F4`
and `$F0`; it finishes with `$F8`. The received byte is complemented by
`EOR #$FF` before being returned to the caller. All reply values below are
these CPU-visible, complemented values.

$1000 bit 7 is also tested in motor handshake/wait paths ($E9F1, $E9FE,
$EC1B). Its exact hardware source remains unresolved. The radio decoder reads
**$1400 bit 7**, a separate CPU address; there is no demonstrated need to
multiplex radio and motor-handshake sources on $1000 bit 7.

## Programmed-motion command bytes

These are actual sequences from $E9FE with operand `n`, initial speed state
$17=0, no active motors, and the initial handshake taking its bit-7-high branch.
`03` is the wheel parameter byte `$17 + 3`; direction-dependent turn variants
are listed separately. The labels follow the firmware's remote operation order.

| Operation / opcode | COP bytes |
|---|---|
| Left / $00, direction state clear | `D5 03 95 n` |
| Forward / $01 | `D3 03 93 n` |
| Reverse / $02 | `E3 03 A3 n` |
| Right / $03, direction state clear | `D4 03 94 n` |
| Wrist up / $04 | `92 n` |
| Wrist down / $05 | `A2 n` |
| Arms up / $06 | `91 n` |
| Arms down / $07 | `A1 n` |
| Claw rotation / $08 | `A0 n` |
| Claw open/close / $09, nonzero operand | `70` |
| Claw open/close / $09, zero operand | `50` |

When $07 bit 0 is set, left uses `E5 03 A5 n` and right uses
`E4 03 A4 n`. Zero operands suppress operations $00–$08.
Busy status groups also prevent overlapping operations. Wheel speed changes
at $E959 resend the selected `D4/D5/E4/E5` command followed by `$17 + 3`.
This establishes a speed-related parameter, not its physical PWM frequency.

## Status and counter requests

| Request | Observed use |
|---|---|
| `B0` | Motor activity/status into $05 |
| `B1` | Additional activity/status into $08 |
| `84` / `44` | Wheel count, ordinary read / completion read |
| `82` / `42` | Wrist count, ordinary read / completion read |
| `81` / `41` | Arm count, ordinary read / completion read |
| `80` / `40` | Claw rotation count, ordinary read / completion read |
| `30` | Additional status into $06 during command reconciliation |

The `4x` requests are used when the CPU closes out a movement and clears its
saved counter state ($ECC5–$ECFF). A read-and-clear operation inside the COP
is plausible but unverified: CPU traces alone cannot establish that side effect.

$05 status groups are bits 0–3 wheels, 4–5 wrist, and 6–7 arms.
Command setup assigns directional pairs within each group. $08 bit 2 is used
for claw open/close activity and bit 3 for claw rotation. Remaining status bits
are unresolved; these are not a complete COP status specification.

## RAM and position bookkeeping

| RAM | Role |
|---|---|
| $03 bit 0 | Arm/wrist coupling configuration |
| $05, $08 | Current activity replies and locally set activity flags |
| $06 | Additional status/control state |
| $07 | Direction bookkeeping: wheel bit 0, wrist bit 4, arm bit 6 |
| $09 bits 6/7 | Flags consulted to inhibit wrist/arm movement; source unresolved |
| $0B, $0C | Previous activity snapshots |
| $12, $13 | Current operation and operand |
| $17, $28 | Wheel speed state and speed-change timer |
| $18, $19, $1A | Wheel position, last stall-check count, previous position-read count |
| $1B, $1C, $1D | Wrist equivalents |
| $1E, $1F, $20 | Arm equivalents |
| $21, $22, $23 | Claw rotation equivalents |
| $29 | Stall-poll interval timer |
| $2A | Motor settling delay timer |

Position reads first undo the previous count contribution, then apply the new
count with the appropriate direction. Thus repeated reads do not repeatedly
add the entire counter. Completion substitutes a `4x` reply and resets the
saved count. Claw rotation folds count values modulo `$55` (85) and wraps its
position at the same modulus ($ECA1–$ECBE).

With $03 bit 0 clear, arms-up sets both arm-up and wrist-down activity
($05=$60); arms-down sets arm-down and wrist-up ($05=$90). With the flag set,
only the arm group is set ($40/$80). This CPU behavior explicitly represents
coupling, although how the COP physically implements it remains unknown.
The movement gates read $09, but its producer has not been established;
do not label these flags as decoded physical limit switches yet.

## Completion, stalls, stop, and home

$E9D0 waits until `B0` is zero and `B1 & $0C` is zero, while also running the
normal service/poll routine. The CPU therefore uses returned activity to wait
for completion rather than directly waiting for encoder pulses.

$EDAF polls when $29 is zero. It requests `B1`, then `B0`, and reads a group's
counter if that group was active both previously and now. A reply equal to the
last saved count branches to **$EE1C**, which stops motors via $E905, displays
`StAL`, increments $A3, and enters the error/return path. Successful polling
sets $29 to 2; interrupt timer servicing decrements it. No wall-clock timeout
is claimed without measuring the interrupt cadence. Claw open/close has no
corresponding encoder-stall comparison in this routine.

The wheel-only stop path sends `03` ($E93D). The all-motor stop path $E905
sends `F8` or `F0` according to the coupling flag, delays, reconciles all four
positions with completion reads, and enters the $EC1B handshake. These serial
command bytes are distinct from similarly valued raw port writes.

Home ($EBDC) sends `60`, `62`, waits for activity to clear, then sends `70`,
`61` and waits again. It initializes positions/counters, including wrist
position $1B=$FF, delays, sends `C0`, and uses `C1` in the final handshake.
These establish a homing sequence; the exact meanings of each command and
which physical limit terminates each phase need COP firmware or bus captures.

## Verification and confidence

[Verification report](motor-control-verification.json) is generated by
[analyze_motors.py](../tools/analyze_motors.py). It executes the original ROM,
checks all 256 possible serial replies, reconstructs transmitted bytes from
actual port writes, checks ten motion operations and turn/claw variants,
arm/wrist coupling, movement gates, successful/stalled polls, and all four
completion-position paths. Poll traces stop at the service or stall branch;
they do not claim to execute the complete robot event loop. Home and stop
sequences above are static code traces, not hardware-verified motion tests.

Confidence is high for the CPU byte sequences, reply inversion, queried
counter channels, RAM bookkeeping, and stall decision. Confidence is moderate
for semantic names attached to COP commands. COP counter reset semantics,
internal motor regulation/debounce, precise encoder mechanics, full limit
status encoding, and physical interface timing remain open.
