#pragma once
#include <stdint.h>
#include "Config.h"
namespace Remote {
constexpr uint32_t KEY_MASK = 0x00ffffffUL;
inline uint8_t encode(uint8_t key, bool release) {
  uint8_t value = key | (release ? 0x20 : 0), count = 0;
  for (uint8_t bits=value; bits; bits>>=1) count += bits&1;
  return value | ((count&3)<<6);
}
inline uint16_t symbols(uint8_t code) {
  uint16_t bits=1;
  for (int8_t shift=7; shift>=0; --shift) {
    bool bit=(code>>shift)&1;
    bits=(bits<<1)|bit;
    if (shift==5 || shift==2) bits=(bits<<1)|!bit;
  }
  return bits;
}
inline uint8_t count(uint32_t bits) {
  uint8_t n=0; for (; bits; bits&=bits-1) ++n; return n;
}
struct Frame { uint8_t key; bool release; };
class Controller {
  uint32_t physical_=0, pc_=0, sent_=0, blocked_=0;
  uint32_t deadline_[24]={}, timed_=0, lastPC_=0;
  bool stop_=false;
  uint8_t round_=0;
public:
  uint32_t physical() const { return physical_; }
  uint32_t pc() const { return pc_; }
  uint32_t active() const { return physical_ | pc_; }
  bool pending() const { return stop_ || sent_ != active(); }
  void stop() {
    // Require currently held physical keys to be released before reactivation.
    blocked_ |= physical_; physical_=pc_=timed_=0; stop_=true;
  }
  void physical(uint32_t keys, bool suppress=false) {
    keys &= KEY_MASK;
    blocked_ &= keys;
    if (suppress) blocked_ |= keys;
    physical_=keys & ~blocked_;
    // A third key invokes the robot's stop path; suppress ambiguous chords.
    if (count(active())>2) { blocked_|=keys; stop(); }
  }
  void contact(uint32_t now) { lastPC_=now; }
  bool down(uint8_t key,uint32_t now,uint16_t duration=0) {
    if (key<1 || key>24) return false;
    uint32_t bit=1UL<<(key-1);
    if ((pc_&bit) || count(active()|bit)>2) return false;
    pc_|=bit; lastPC_=now;
    if (duration) { timed_|=bit; deadline_[key-1]=now+duration; }
    return true;
  }
  void up(uint8_t key) {
    if (key<1 || key>24) return;
    uint32_t bit=1UL<<(key-1); pc_&=~bit; timed_&=~bit;
  }
  void advance(uint32_t now) {
    if (pc_ && uint32_t(now-lastPC_)>=Config::PC_LEASE_MS) { stop(); return; }
    for (uint8_t i=0;i<24;++i)
      if ((timed_&(1UL<<i)) && int32_t(now-deadline_[i])>=0) up(i+1);
  }
  bool next(Frame &f) {
    if (stop_) { stop_=false; sent_=0; f={25,false}; return true; }
    uint32_t desired=active();
    uint32_t changes=sent_&~desired; // Release before admitting another key.
    bool release=true;
    if (!changes) { changes=desired&~sent_; release=false; }
    if (changes) {
      uint8_t i=0; while (!(changes&(1UL<<i))) ++i;
      if (release) sent_&=~(1UL<<i); else sent_|=1UL<<i;
      f={uint8_t(i+1),release}; return true;
    }
    for (uint8_t n=0;n<24;++n) {
      uint8_t i=round_; round_=(round_+1)%24;
      if (desired&(1UL<<i)) { f={uint8_t(i+1),false}; return true; }
    }
    return false;
  }
};
// Whole-matrix debounce and conservative diode-less ghost rejection.
inline bool ambiguous(uint32_t keys) {
  uint8_t occupied=0;
  for (uint8_t row=0;row<6;++row) {
    uint8_t cols=(keys>>(row*4))&15;
    if (cols) ++occupied;
  }
  return occupied>1 && count(keys)>2;
}
class Debouncer {
  uint32_t candidate_=0, stable_=0, since_=0;
public:
  uint32_t update(uint32_t raw,uint32_t now) {
    if (raw!=candidate_) { candidate_=raw; since_=now; }
    if (uint32_t(now-since_)>=Config::DEBOUNCE_MS) stable_=candidate_;
    return stable_;
  }
};
}
