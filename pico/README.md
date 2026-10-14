# Pico USB remote emulator

MicroPython firmware for an RP2040 Raspberry Pi Pico. A PC sends text commands
through the Pico's USB CDC serial port; GPIO2 generates the Maxx Steele remote
signal using hardware PIO. A Windows console client is included in `pc/`.

The encoding is derived from the robot ROM and confirmed by 261 complete frames
in 23 receiver captures. Lamp and Power/Stop codes are ROM-derived predictions.
See [remote protocol](../docs/remote-protocol.md). The cartridge templates are
unchanged.

## Hardware connection

- Default output: **GP2, physical pin 4** on the original Pico.
- Ground: for example **physical pin 3**.
- Power/PC communication: the Pico USB port.
- GP2 is a **3.3 V output and is not 5 V tolerant**.

The transmitter jack's pinout, input voltage, and polarity are not established.
Do not connect it directly to GP2 until those are determined. Use the appropriate
buffer/level translator or transistor interface and a common signal reference.
The capture note `Green GND / Blue Signal / Gray 5V` describes the receiver
connection; it does not establish the transmitter jack pinout. The Pico generates
baseband control, not a 27 MHz RF carrier.

Set `INVERT_OUTPUT` in `config.py` to compensate for interface/transmitter
inversion after measurement. Default is high start/data-1 and low idle, matching
the receiver captures. An inverting transistor stage may require the opposite
setting. Test the GPIO waveform with a logic analyzer before attaching the
transmitter. PIO state machine 0 and GP2 must be available to this firmware.

## Install on the Pico

1. Install the official **MicroPython RP2040/Pico UF2** from
   https://micropython.org/download/RPI_PICO/ using BOOTSEL mode.
2. Edit `config.py` for the GPIO and measured polarity.
3. Using Thonny or another MicroPython file-transfer tool, copy these four files
   into the Pico filesystem root: `main.py`, `config.py`, `controller.py`,
   and `protocol.py`. Do not copy the host verification tools to the Pico.
4. Restart the Pico. `main.py` runs automatically and emits a JSON ready message
   over USB. Close Thonny's serial connection before opening the PC client.

Use the standard USB CDC port (for example COM5 on Windows). There is no custom
USB driver/protocol, and no UART pins are required. The PC client's 115200 serial
setting does not determine the remote symbol rate: PIO runs independently.

## Windows PC client

```powershell
py -m pip install pyserial==3.5
py pc/remote_cli.py COM5
```

The client sends a keepalive every 500 ms while the console is open. Examples:

```text
TAP ENTER
TAP FORWARD 100
DOWN FORWARD
UP FORWARD
TAP PROGRAM
TAP MOTION
TAP 1
TAP ENTER
STATUS
KEYS
STOP
QUIT
```

Use `KEYS` for the complete list. `0`–`9` mean the physical numbered keys;
`1` and `FORWARD` are aliases for the same key. Commands act like remote keys
and depend on the robot's current mode; this interface does not bypass firmware
or reinterpret program steps. Wait for the robot's prompts where appropriate.

| Command | Behavior |
|---|---|
| `TAP KEY [ms]` | Press, repeat while held, then release; duration from command acceptance, default 100 ms, range 60–60000 ms |
| `DOWN KEY` | Hold until `UP`, `STOP`, or keepalive expiry |
| `UP KEY` | Release a currently held key; an already released key is a no-op |
| `STOP` | Cancel software-pending commands, send Power/Stop, then release held keys |
| `PING` | Refresh the two-second USB contact lease |
| `STATUS` | List held keys and software queue length |
| `KEYS` | List canonical names |

At most two keys can be held. Repeating a `DOWN` for an already held key is an
error, not a new press. Power/Stop is sent once rather than continuously held.
The firmware continues generating held repeats without blocking USB input. If
the PC disappears while keys are held, it queues Stop and releases after two
seconds. A tap can also expire sooner. The lease is a fallback, not a hard
guarantee that the robot physically stopped: an RF loss or unverified stop code
can prevent reception, and the robot also has its own held-key timeout.

Replies are newline-delimited JSON. `ok: true` means the command was accepted
or queued by the Pico; it is **not acknowledgement from the robot**. A ready
message precedes commands after boot. Plain serial terminals can send commands,
but must send `PING` or another valid command at least every two seconds to
maintain a held key. Input lines are limited to 96 characters and the software
event queue to 32 entries. `STOP` remains accepted if the queue is full.

## Timing and latency

Default PIO clock: 1 MHz. Symbol time: 1,578 microseconds. Eleven frame symbols
take 17,358 microseconds; low idle is 11,570 microseconds. Continuous frames
start every 28,928 microseconds, matching the capture median repeat interval.
The physical idle is high when output inversion is enabled.
Queue delays can shorten the time between a tap's actual on-air press and
release relative to the requested duration; avoid queuing long key sequences
at once when hold duration matters.

One FIFO frame can be waiting while another is transmitting. A new USB event
waits behind those frames; this avoids cutting a frame in half but can introduce
up to roughly two frame periods before it starts. Pending commands add further
delay. With two held keys their repeat frames alternate, refreshing each about
every 57.856 ms. Changes in USB processing can extend idle gaps, while PIO keeps
each frame's symbol durations stable. Flooding the interface should be avoided.

The PIO loop uses `symbol_us - 4` delay counts and packs `gap_us - 5` into its
word; those offsets include actual instruction cycles. Host tests interpret the
PIO instructions parsed directly from `main.py`, check pin-write intervals,
and replay their generated waveforms through the original robot ROM.

## Verification and current limits

From the repository root, using a host environment with `py65==1.2.0` and
`pyserial==3.5`:

```sh
MAXX_ROM=/path/to/Maxx_Steele_Main_Mapped.bin \
  /workspace/.venvs/maxx-steele/bin/python -m unittest discover -s tests -v
```

On Windows, optional host verification can be run with:

```powershell
py -m pip install py65==1.2.0 pyserial==3.5
$env:MAXX_ROM = "C:\path\to\Maxx_Steele_Main_Mapped.bin"
py -m unittest discover -s tests -v
```

The checks cover every key's encoding, PIO timing and inversion, generated
press/release acceptance in the original ROM, two-key scheduling, tap expiry,
keepalive expiry, queue saturation, Stop priority, and clock-counter wrap.
USB-client line exchange is checked with a simulated serial port. Both PIO
polarity variants were also compiled using the official MicroPython v1.26.0
Python PIO assembler, with native hardware definitions stubbed on the host.

No physical Pico is attached to the development environment. On-device
MicroPython operation, USB CDC operation, GPIO timing, transmitter-jack compatibility,
and robot response still require hardware validation. This is an implementation
ready to flash and test, not a claim of a completed physical interface. To
recover the MicroPython REPL, Ctrl-C in a serial terminal interrupts the main
loop; cleanup attempts Stop/releases and then restores the output to idle.
BOOTSEL remains available for reflashing.
