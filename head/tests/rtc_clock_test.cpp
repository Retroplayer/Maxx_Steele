#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../MaxxHead/RTCClock.h"
struct Bus {
  uint8_t r[0x13] = {};
  int writes=0, failAt=-1;
  bool missing=false;
  bool read(uint8_t reg,uint8_t *out,uint8_t count) {
    if (missing) return false;
    memcpy(out,r+reg,count); return true;
  }
  bool write(uint8_t reg,const uint8_t *data,uint8_t count) {
    if (++writes==failAt) return false;
    memcpy(r+reg,data,count); return true;
  }
};
int main() {
  Bus fresh; fresh.r[15]=0x8b; fresh.r[14]=0x83;
  assert(RTCClock::ensure(fresh)==RTCClock::Initialized);
  const uint8_t expected[]={0,0,0,1,0x25,0x12,0x84};
  assert(!memcmp(fresh.r,expected,7));
  assert(fresh.r[15]==8 && fresh.r[14]==4);
  assert(fresh.r[7]==0 && fresh.r[8]==0 && fresh.r[9]==7 && fresh.r[10]==0x80);
  int writes=fresh.writes;
  assert(RTCClock::ensure(fresh)==RTCClock::Ready && fresh.writes==writes);
  // A healthy clock and latched alarm survive startup unchanged.
  fresh.r[0]=0x56; fresh.r[1]=0x34; fresh.r[2]=0x19;
  fresh.r[3]=0; // Weekday deliberately unused, even if outside normal 1..7.
  fresh.r[4]=0x16; fresh.r[5]=0x90; fresh.r[6]=0x26;
  fresh.r[14]=5; fresh.r[15]=9;
  uint8_t retained[0x13]; memcpy(retained,fresh.r,sizeof retained);
  assert(RTCClock::ensure(fresh)==RTCClock::Ready);
  assert(!memcmp(retained,fresh.r,sizeof retained));
  // Oscillator backup enable can be repaired without altering time or alarms.
  fresh.r[14]|=0x80;
  assert(RTCClock::ensure(fresh)==RTCClock::Ready && fresh.r[14]==5);
  assert(!memcmp(retained,fresh.r,sizeof retained));
  for(int fail=1;fail<=5;++fail) {
    Bus broken; broken.r[15]=0x80; broken.failAt=fail;
    assert(RTCClock::ensure(broken)==RTCClock::Failed);
    assert(broken.r[15]&0x80);
    broken.failAt=-1;
    assert(RTCClock::ensure(broken)==RTCClock::Initialized);
  }
  Bus corrupt; corrupt.r[0]=0x7f;
  assert(RTCClock::ensure(corrupt)==RTCClock::Initialized);
  Bus absent; absent.missing=true;
  assert(RTCClock::ensure(absent)==RTCClock::Missing && absent.writes==0);
  assert(RTCClock::daysInMonth(1984,2)==29 && RTCClock::daysInMonth(2026,2)==28);
  assert(RTCClock::daysInMonth(2000,2)==29 && RTCClock::daysInMonth(1900,2)==28);
  assert(RTCClock::monthRegister(1984,1)==1 && RTCClock::monthRegister(2026,10)==0x90);
  puts("PASS: invalid RTC midnight defaults, retained clock/alarm, unused weekday, failed writes/retry, missing RTC, calendar checks");
}
