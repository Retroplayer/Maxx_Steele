#include <assert.h>
#include <stdio.h>
#include "../MaxxHead/Protocol.h"
struct Events : HeadEvents {
  int updates = 0, commands = 0;
  uint8_t lastCommand = 0;
  void changed() override { ++updates; }
  void command(uint8_t value) override { ++commands; lastCommand = value; }
};
void frame(HeadProtocol &p, const uint8_t *glyphs) {
  p.feed(0xe3); p.feed(0xf3);
  for (int i = 0; i < 4; ++i) p.feed(glyphs[i]);
  p.feed(0xe2);
}
int main() {
  Events events; HeadProtocol p(events);
  for (int i = 0; i < 32; ++i) {
    frame(p, messages[i].glyphs);
    assert(p.state.view == HeadState::MessageView && p.state.message == i);
  }
  uint8_t collisions[] = {0xe3, 0xf3, 0xe2, 0xe5};
  frame(p, collisions);
  assert(p.state.view == HeadState::Raw && !memcmp(p.state.glyphs, collisions, 4));
  int updates = events.updates;
  p.feed(0xe3); p.feed(0xf3); for (int i=0; i<4; ++i) p.feed(0);
  p.feed(0x12); assert(events.updates == updates);
  frame(p, messages[6].glyphs); assert(p.state.message == 6);
  uint8_t withDot[4]; memcpy(withDot, messages[6].glyphs, 4); withDot[0] |= 1;
  frame(p, withDot); assert(p.state.view == HeadState::Raw);
  p.feed(0xe1); p.feed(0xeb); assert(p.state.alarmEnabled);
  p.feed(0xee); assert(!p.state.alarmEnabled);
  p.state.alarmHour=23; p.state.alarmMinute=59;
  p.feed(0xea); p.feed(0xe9); assert(!p.state.alarmHour && !p.state.alarmMinute);
  p.feed(0xe5); assert(p.state.view == HeadState::Sleeping);
  p.feed(0xe6); assert(p.state.view == HeadState::Clock);
  // Stock clock menu delegates these operations to the RTC adapter. Verify
  // neither is swallowed and that startup E6 doesn't discard alarm settings.
  const uint8_t timeCommands[] = {0xe7, 0xe8};
  for (uint8_t command : timeCommands) {
    int calls = events.commands;
    p.feed(command);
    assert(events.commands == calls + 1 && events.lastCommand == command);
  }
  p.state.alarmHour = 13; p.state.alarmMinute = 42; p.feed(0xeb);
  p.feed(0xe6);
  assert(p.state.alarmHour == 13 && p.state.alarmMinute == 42 && p.state.alarmEnabled);
  p.feed(0xe3); p.feed(0xf3); p.feed(1); p.resetFraming();
  frame(p, messages[31].glyphs); assert(p.state.message == 31);
  for (int lsb=0; lsb<2; ++lsb) for(int invert=0; invert<2; ++invert)
    for (int n=0; n<256; ++n) {
      BitReceiver bits(lsb, invert); uint8_t out=0;
      for(int i=0; i<8; ++i) {
        bool bit = ((n >> (lsb ? i : 7-i)) & 1) ^ invert;
        assert(bits.sample(bit, out) == (i == 7));
      }
      assert(out == n);
    }
  puts("PASS: 32 presets, command-valued glyphs, malformed frames, decimal points, clock/alarm/sleep, reset, 1024 byte reception cases");
}
