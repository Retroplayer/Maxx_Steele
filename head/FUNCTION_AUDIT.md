# Head replacement completeness audit

Compared the prototype against all named SendHeadByte/BeginHeadDisplayFrame
callers in the reconstructed stock assembly, the existing CPU trace tool,
the owner manual's time/alarm instructions (PDF pages 9–10), and the schematic
head connections. This audits the **current prototype**, not original COP
internals. The full Arduino sketch is still uncompiled/unflashed in this
environment; host tests exercise only the portable parser/bit receiver.

## Known serial command coverage

| Stock stream | Purpose | Current implementation |
|---|---|---|
| E3 F3 + four glyphs + E2 | Display update | Atomic frame parser, exact stock preset translations, raw fallback |
| E0 | Clock display | Implemented; presentation differs from original |
| E1 | Alarm display | Implemented; presentation differs from original |
| E8 / E7 | Advance clock hour/minute | RTC writes implemented; invalid-clock initialization incomplete |
| EA / E9 | Advance alarm hour/minute | Working state increment and RTC Alarm 1 programming implemented |
| EB | Alarm enable | Implemented working interpretation of stock callers |
| EE | Alarm disable/acknowledge | Disables Alarm 1 and clears flags |
| E5 | Sleep request | Sleep screen plus generic optional power output; not verified board behavior |
| E6 | Startup/wake | Clock view plus generic optional power output; preserves RTC time |

No additional distinct head command was identified in the reviewed stock
callers. E2/E3/F3 are understood in the observed seven-byte transaction, not
claimed as a complete specification of every possible standalone COP command.
Payload bytes equal to command values remain glyphs while loading a frame.

Repeated E7/E8/E9/EA commands are accepted, so remote held-key acceleration
remains under main-CPU control. Program auto-execution and the audible alarm
tune are main-CPU responsibilities, not missing head synthesis functions.

## Missing or incomplete software behavior

1. **Original 12-hour display and PM indication.** Sketch renders 00–23 without
   AM/PM. Manual specifies 12-hour display and upper-left PM point. Store time
   internally as 24-hour if desired, but present 12-hour time for compatibility.
2. **Blinking colon.** Original manual specifies blinking every second. Current
   renderer has a static colon and ordinarily redraws only on minute changes.
3. **Remote-only initial clock setup.** E7/E8 write registers but never clear
   DS3231 OSF. On a fresh/invalid RTC, setting the clock with the remote alone
   can leave the display at `--:--`. USB timestamp setup clears OSF, so the
   prototype presently depends on USB initialization. Need a defined initial
   calendar/time and a deliberate validity transition after remote setting.
4. **Original unset-clock indication.** The original blinks 12:00 after power
   interruption. Prototype shows static `--:--`/SET RTC. Choose and implement
   the OLED equivalent; do not overwrite a valid battery-backed clock on E6.
5. **I2C failure/state handling.** RTC writes are not consistently checked;
   software alarm state can say ON even when hardware programming fails.
   RTC presence/validity changes do not always trigger a display refresh.
6. **Time-adjust feedback latency.** E7/E8 mark the display dirty before the
   next RTC poll updates hourNow/minuteNow, so immediate rendering can show
   the old value until the poll. Needs prompt readback/state update.
7. **Alarm restore validation.** Startup reads alarm hour/minute and enable,
   but does not fully validate date masks, seconds, mode, or enforce the
   expected daily Alarm 1 configuration. Power-loss/reset tests are needed.
8. **Cold-start alarm ownership.** Main CPU $04 bit 7 tracks its own enable
   state; DS3231 can preserve enable independently through a cold start. Need
   a policy to keep main CPU and replacement head consistent without silently
   changing normal warm-reset behavior. E6 alone does not reveal reset type.

The original alarm is re-armed manually after each use (manual page 10). The
prototype's hardware Alarm 1 is daily, but EE from the main CPU disables it on
acknowledgement. Normal one-shot behavior therefore depends on that handshake;
it has not been verified on Maxx. No audible alarm needs adding to the head.

## Display enhancements versus compatibility

Raw numeric, mixed command/operand, game, music-note, sharp, and octave displays
can render through the generic segment fallback. They are **not yet expanded
into descriptive text**. All segment bits/decimal points are retained, but
translation currently covers only the 32 exact stock preset frames.

Custom cartridge text and e-paper rendering are not implemented. They are
future enhancements, not unhandled stock commands. The purchased SH1122 OLED
matches the sketch's driver selection.

## Physical board replacement gaps

- **ALARMB:** Low-active output logic exists, but DRIVE_ALARM defaults off.
  External level/open-drain interfacing and actual main-CPU acknowledgement
  need verification. DS3231 INT/SQW is not used; the MCU polls its flag.
- **Sleep/wake:** DRIVE_POWER defaults off. Its generic output is not yet a
  verified implementation of head POWERB. POWERB and ASIC POWER ENABLE B are
  distinct; the head cannot be treated as directly controlling Q100.
- **Manual wake/reset:** Head STOP switch and master-reset path need retained
  wiring/behavior. No firmware input handling has been assigned to them.
- **Other clock/control nets:** Schematic labels F4MHZ, F244HZ, ALARM DATA CLK,
  and COPCKB require a connector contract. COPCKB reception is assigned; the
  others aren't implemented. Establish which are inputs, outputs, or original
  COP-only clock needs before deciding which must be reproduced. In particular,
  do not invent a mandatory F244HZ output without tracing its direction.
- **Photocell:** It is not controlled by the COP. Preserve its existing
  pass-through/component connection to the main-board comparator; no invented
  serial photocell command or MCU sampling is required.
- **Supplies:** VC/VBAT/GND and the replacement's always-on 3.3 V supply must be
  allocated. DS3231 battery backup alone cannot keep the Pico awake.
- **Reception alignment:** Configurable edge/inversion/bit order exists, but
  MCU startup mid-byte, missed clocks, and queue overflow need bench validation
  and a robust recovery policy. Display updates must not drop input edges.

## Verification performed

Re-ran `tools/analyze_head_display.py` against the original mapped ROM:
32 presets, 256 BCD values, two numeric formatters, all 256 sender byte values
on each COP path, 115 mixed-format cases, decimal points, and four clock/alarm
adjustment pairs passed. This validates CPU-side behavior, not the new RTC
adapter or an original head COP.

Extended portable tests verify E7/E8 reach the RTC adapter callback and E6
preserves the alarm state, alongside existing frame/command/bit-order tests.
No hardware timing, power transition, RTC alarm delivery, or full sketch build
is claimed by those tests.

**Conclusion:** no known stock head command is absent from the parser, but
clock presentation, first-time setting, error handling, and several physical
connections remain unfinished. This is a display/RTC bench prototype, not yet
a functionally complete replacement head board.
