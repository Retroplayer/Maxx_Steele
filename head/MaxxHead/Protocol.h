#pragma once
#include <stdint.h>
#include <string.h>
#include "Messages.h"
#include "DisplayUI.h"

// No Arduino dependencies: the same parser is exercised by host tests.
struct HeadState {
  enum View { Clock, Alarm, MessageView, Raw, Sleeping } view = Clock;
  uint8_t glyphs[4] = {};
  int message = -1;
  bool alarmEnabled = false;
  uint8_t alarmHour = 7, alarmMinute = 0;
  DisplayUI ui;
};

struct HeadEvents {
  virtual ~HeadEvents() = default;
  virtual void changed() = 0;
  virtual void command(uint8_t value) = 0;
};

class HeadProtocol {
 public:
  HeadState state;
  explicit HeadProtocol(HeadEvents &events) : events(events) {}
  void resetFraming() { phase = Idle; count = 0; state.ui.reset(); }
  void feed(uint8_t byte) {
    // Glyphs may equal commands, including E3/F3/E2. Never decode them here.
    if (phase == Glyphs) {
      pending[count++] = byte;
      if (count == 4) phase = Apply;
      return;
    }
    if (phase == Apply) {
      phase = Idle;
      if (byte == 0xe2) {
        memcpy(state.glyphs, pending, 4);
        state.message = -1;
        for (unsigned i = 0; i < sizeof(messages) / sizeof(messages[0]); ++i)
          if (!memcmp(pending, messages[i].glyphs, 4)) { state.message = i; break; }
        state.view = state.message >= 0 ? HeadState::MessageView : HeadState::Raw;
        state.ui.frame(state.glyphs, state.message);
        events.changed();
        return;
      }
      // Reject incomplete frame; reconsider this byte as a command/prefix.
    }
    if (phase == Prefix) {
      phase = Idle;
      if (byte == 0xf3) { count = 0; phase = Glyphs; return; }
    }
    if (byte == 0xe3) { phase = Prefix; return; }
    switch (byte) {
      case 0xe0: state.view = HeadState::Clock; break;
      case 0xe1: state.view = HeadState::Alarm; break;
      case 0xe5: state.view = HeadState::Sleeping; break;
      case 0xe6: state.view = HeadState::Clock; break;
      case 0xeb: state.alarmEnabled = true; break;
      case 0xee: state.alarmEnabled = false; break;
      case 0xe7: case 0xe8: break; // RTC adjustments are performed by adapter.
      case 0xe9: state.alarmMinute = (state.alarmMinute + 1) % 60; break;
      case 0xea: state.alarmHour = (state.alarmHour + 1) % 24; break;
      default: return;
    }
    events.command(byte);
    state.ui.command(byte);
    events.changed();
  }
 private:
  enum Phase { Idle, Prefix, Glyphs, Apply } phase = Idle;
  uint8_t pending[4] = {}, count = 0;
  HeadEvents &events;
};

class BitReceiver {
 public:
  BitReceiver(bool lsbFirst = false, bool invertData = false)
      : lsb(lsbFirst), invert(invertData) {}
  void reset() { value = bits = 0; }
  bool sample(bool level, uint8_t &out) {
    const uint8_t bit = level ^ invert;
    if (lsb) value |= bit << bits;
    else value = (value << 1) | bit;
    if (++bits != 8) return false;
    out = value; reset(); return true;
  }
 private:
  bool lsb, invert;
  uint8_t value = 0, bits = 0;
};
