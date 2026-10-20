# Context-aware head display

The new layout keeps a large mode announcement on entry. Subsequent dynamic
frames show a small action label above a large value, while the bottom line
retains mode and useful context. Alarm status is no longer the footer's main
content during programming. Clock/alarm views retain their own status display;
sleep shows time in the footer rather than repeating 'Alarm off'.

## Evidence and implemented behavior

Sources: owner manual sections 4.2–4.6 (PDF pages 13–27), original ROM
$F64E–$F735 (entry formatting), $F0D0–$F144 (music editor), $F9ED–$FA09
(game prompts/single score), and $FBCE/$FC34 (Force Field level/dual scores).
No remote key events or hidden COP state are assumed available to the new head.

| Received sequence | Main area | Persistent footer |
|---|---|---|
| Prog | Large Program mode announcement | PROGRAM |
| Program position 000 | Program step / 000 | PROGRAM / STEP 000 |
| F___ then F 12 | Forward / Enter value, then 12 | PROGRAM / STEP 000 |
| Position 001 | Program step / 001 | PROGRAM / STEP 001 |
| PS__ then PS 2 then S 65 | Edit sentence / 2, then Word code / 65 | PROGRAM / SENTENCE 2 |
| Prog, Song, 00F3 | Note 00 / F, duration key 3 | PROGRAM / MUSIC |
| FULL, StAL, bAd, bEg/End | Readable existing message | Underlying mode/context preserved |
| PLAy, selection/setup, zero-filled scores | Separate YOU and MAXX score columns when Force Field is inferred | GAME / FORCE FIELD |

Motion amounts remain native values; no unverified conversion to inches or
degrees is applied. Wait shows seconds. Claw 0=Open, 1=Close and lamp 0=Off,
1=On follow the manual. An underscore is an empty-entry prompt, not zero.
Values are not described as saved or accepted merely because they appeared:
ENTER is not transmitted as an independent head event.

Preset learn/program/execute/game messages establish the main mode. Song,
speech, sentence and settings messages establish an activity without erasing
that main mode. The distinct PS prefix establishes speech editing, so later S
frames retain the sentence being edited. No word-slot count is invented because
editing/backtracking and ENTER cannot reliably be distinguished from this bus.

The song editor starts with Song, **not necessarily notE**. A matching numeric
position/pitch/duration frame transitions that activity to MUSIC. Position and
octave/sharp indicators are decoded from the actual segment format. Durations
are shown as the original duration-key codes; named lengths and 100–126 note
positions cannot be invented from a two-digit position display.

## Games and ambiguity

The manual confirms Moon Ball uses a single score, while Force Field has the
player on the left and Maxx on the right. The latter routine sends four
zero-filled digits; its intermission level uses a blanked numeric display.

The game choice and difficulty routines emit the same single-digit prompt.
After PLAy, a displayed 0/1 followed by a fresh prompt is treated as game choice
followed by setup. This is a **heuristic**: a retry can look the same. A
Force Field score layout requires both that inferred choice and the four-digit
zero-filled numeric format. Blanked intermission values retain the neutral
label Game value. Moon Ball values 0–3 initially remain Game value because
difficulty and a low score overlap; once a value above 3 appears, later values
can be shown as Score in the retained Moon Ball context.

The head cannot reliably infer every game phase, player action, rejection,
or retry without firmware changes. This implementation does not claim it can.

E0 clock return and E6 initialization clear entry context to prevent a stale
PROGRAM/GAME label after an exit. Reception reset/overflow clears inferred UI
context too, while retaining RTC/alarm state. Unrecognized glyphs retain the
original segments and decimal points under the last known mode.

## Bench preview and tests

Send **u** in USB Serial Monitor to advance through 22 demo frames: program
entry, sentence editing, a warning, music editing, game setup, dual scores, and
an intermission value. **n** still cycles all stock presets. These commands
inject frames into the same parser; use them with the robot bus idle/disconnected.

```sh
g++ -std=c++11 -Wall -Wextra -Werror -pedantic head/tests/ui_test.cpp -o /tmp/head-ui-test
/tmp/head-ui-test
python tools/check_head_ui.py --rom /path/to/Maxx_Steele_Main_Mapped.bin
```

The second command requires py65 and executes stock ROM routines to supply
1,672 prompt/value frames: every legal operand of 16 supported command types.
Sequence tests cover context retention, errors, speech editing, music and game
scores, ambiguous values, and reset. The updated sketch still needs an Arduino
build and board test; the user has already demonstrated the previous SH1122
prototype's display and RTC views on hardware.

This change addresses entry UI only. It does not resolve the outstanding direct
DS3231-to-ALARMB wiring/low-power redesign, other head clock/discrete connections,
and 12-hour/PM presentation listed in FUNCTION_AUDIT. Invalid-RTC initialization
is now covered separately in [RTC_INITIALIZATION.md](RTC_INITIALIZATION.md).
