#pragma once
#include <stdint.h>

namespace RTCClock {
// Owner-selected historical placeholder: Christmas Day, 1984; not a claim
// about the robot's exact release date.
// No date/weekday is shown. Our century convention is 1900 + C*100 + YY;
// the DS3231 itself stores YY and a rollover bit, not an absolute century.
constexpr unsigned DEFAULT_YEAR = 1984;
constexpr uint8_t DEFAULT_MONTH = 12, DEFAULT_DAY = 25;
inline uint8_t bcd(unsigned value) { return ((value/10)<<4) | (value%10); }
inline unsigned decimal(uint8_t value) { return (value>>4)*10 + (value&15); }
inline bool validBCD(uint8_t value, unsigned low, unsigned high) {
  return (value&15)<10 && (value>>4)<10 && decimal(value)>=low && decimal(value)<=high;
}
inline unsigned daysInMonth(unsigned year, unsigned month) {
  static const uint8_t days[] = {31,28,31,30,31,30,31,31,30,31,30,31};
  if (month<1 || month>12) return 0;
  bool leap = year%4==0 && (year%100!=0 || year%400==0);
  return days[month-1] + (month==2 && leap);
}
inline uint8_t monthRegister(unsigned year, unsigned month) {
  return bcd(month) | (year>=2000 ? 0x80 : 0);
}
inline bool validCalendar(const uint8_t *r) {
  if (r[0]&0x80 || r[1]&0x80 || r[2]&0x80 || r[4]&0xc0 || r[5]&0x60) return false;
  bool hour = (r[2]&0x40) ? validBCD(r[2]&0x1f,1,12) : validBCD(r[2]&0x3f,0,23);
  if (!validBCD(r[0],0,59) || !validBCD(r[1],0,59) || !hour ||
      !validBCD(r[5]&0x1f,1,12) || !validBCD(r[6],0,99)) return false;
  unsigned year = 1900 + ((r[5]&0x80) ? 100 : 0) + decimal(r[6]);
  // Weekday is deliberately ignored: Maxx has no weekday concept.
  return validBCD(r[4],1,daysInMonth(year,decimal(r[5]&0x1f)));
}
enum Result { Missing, Failed, Ready, Initialized };

// Bus supplies bool read(reg, bytes, count) and bool write(reg, bytes, count).
// OSF=1 means invalid/stopped, not valid. Clear it only after successful
// initialization; preserve a healthy retained clock, including date and alarms.
template<class Bus> Result ensure(Bus &bus) {
  uint8_t time[7], status, control;
  if (!bus.read(0x0f,&status,1)) return Missing;
  if (!bus.read(0,time,7) || !bus.read(0x0e,&control,1)) return Failed;
  if (!(status&0x80) && validCalendar(time)) {
    if (control&0x80) {
      control &= ~0x80; // Keep oscillator running on battery backup too.
      if (!bus.write(0x0e,&control,1)) return Failed;
    }
    return Ready;
  }
  // Mark invalid before attempting repairs, including when corruption rather
  // than OSF caused initialization. A partial failure must not appear valid.
  uint8_t invalid = status | 0x80;
  if (!bus.write(0x0f,&invalid,1)) return Failed;
  control = (control & ~0x83) | 0x04; // Oscillator enabled, INTCN=1, alarms off.
  if (!bus.write(0x0e,&control,1)) return Failed;
  const uint8_t initial[] = {0,0,0,1,bcd(DEFAULT_DAY),
                            monthRegister(DEFAULT_YEAR,DEFAULT_MONTH),bcd(DEFAULT_YEAR%100)};
  if (!bus.write(0,initial,7)) return Failed;
  const uint8_t alarm[] = {0,0,0x07,0x80}; // Defined disabled daily alarm: 07:00.
  if (!bus.write(7,alarm,4)) return Failed;
  if (!bus.read(0,time,7) || !validCalendar(time)) return Failed;
  if (!bus.read(0x0f,&status,1)) return Failed;
  status &= ~0x83; // Clear OSF and stale alarm flags; preserve other flags.
  if (!bus.write(0x0f,&status,1)) return Failed;
  if (!bus.read(0x0f,&status,1) || (status&0x80)) return Failed;
  return Initialized;
}
} // namespace RTCClock
