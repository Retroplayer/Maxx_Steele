# RTC initialization policy

Maxx has no date/weekday interface. The OLED never displays a date or weekday,
and remote time adjustment changes only hours/minutes. No weekday calculation
or weekday UI is implemented.

The DS3231 does not have a separate date-valid flag. Its **OSF** (status $0F
bit 7) is set when the oscillator has stopped; zero means no recorded oscillator
failure since it was cleared. Firmware also checks BCD time and calendar ranges.
An absent/unresponsive RTC remains an error, not a fabricated working clock.

When OSF is set or registers contain an invalid time/calendar:

1. Enable the oscillator, select alarm interrupt mode, and disable both alarms.
2. Set **00:00:00, December 25, 1984**, the owner's chosen historical default.
   This is not presented as an exact release date.
3. Write a fixed unused weekday value of 1, without calculating it.
4. Initialize disabled daily Alarm 1 to 07:00:00.
5. Clear stale alarm flags and OSF after successful initialization/readback.

A healthy retained clock is not reset by startup/E6. Its time, calendar, alarm,
and latched alarm flag are preserved. If backup oscillator operation is disabled
by EOSC, firmware clears that control bit without changing the retained time.
Checks also run on polling, so a newly connected invalid RTC can initialize.

RTC date encoding uses year 84 and month $12 for the historical default. The
firmware's century convention is **1900 + century_bit*100 + year**; the DS3231
itself supplies a two-digit year and a century rollover bit, not an absolute
epoch. USB timestamp writes for 2000–2099 set the month century bit accordingly.
External libraries using a fixed 2000 epoch may label the default as 2084; no
such date conversion or date output is used by Maxx's display. Existing valid
RTC contents from earlier firmware are preserved, not migrated.

The USB timestamp command remains available as a diagnostic setting mechanism;
weekday stays a fixed unused value. Normal use does not need USB date entry:
the default establishes valid clock registers, then remote hour/minute commands
set the desired time while leaving the hidden calendar alone.

Reproduce host tests:

```sh
g++ -std=c++11 -Wall -Wextra -Werror -pedantic head/tests/rtc_clock_test.cpp -o /tmp/maxx-rtc-test
/tmp/maxx-rtc-test
```

Tests cover fresh/invalid registers, Christmas-midnight initialization, retained
time and alarm flags, disabled backup oscillator, absent device, failed writes
and retry, and calendar ranges. They simulate register I/O and do not replace a
physical DS3231 test. Full updated-sketch compilation remains a board-toolchain
check; prior versions were compiled and displayed successfully by the owner.
