#include <Arduino.h>
#include <Wire.h>
#include <U8g2lib.h>
#include "Config.h"
#include "Protocol.h"

// Confirm controller against the purchased module. 2.08-inch panels are not
// interchangeable merely because they have the same size and pixel count.
U8G2_SH1122_256X64_F_4W_SW_SPI screen(U8G2_R0, OLED_CLOCK, OLED_DATA,
                                      OLED_CS, OLED_DC, OLED_RESET);
struct Events : HeadEvents {
  void changed() override;
  void command(uint8_t value) override;
} events;
HeadProtocol protocol(events);
BitReceiver receiver(LSB_FIRST, INVERT_DATA);
volatile uint8_t queueBytes[256];
volatile uint8_t producer = 0, consumer = 0;
volatile bool overflow = false;
volatile uint32_t lastEdge = 0;
bool dirty = true, rtcPresent = false, rtcValid = false, alarmAsserted = false;
uint32_t lastPoll = 0;
uint8_t hourNow = 0, minuteNow = 0;

uint8_t bcd(uint8_t n) { return ((n / 10) << 4) | (n % 10); }
uint8_t decimal(uint8_t n) { return (n >> 4) * 10 + (n & 15); }
uint8_t decodeHour(uint8_t n) {
  if (n & 0x40) return decimal(n & 0x1f) % 12 + ((n & 0x20) ? 12 : 0);
  return decimal(n & 0x3f);
}
bool readRTC(uint8_t reg, uint8_t *out, uint8_t length) {
  Wire.beginTransmission(0x68); Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(0x68, (int)length) != length) return false;
  for (uint8_t i = 0; i < length; ++i) out[i] = Wire.read();
  return true;
}
bool writeRTC(uint8_t reg, const uint8_t *data, uint8_t length) {
  Wire.beginTransmission(0x68); Wire.write(reg); Wire.write(data, length);
  return Wire.endTransmission() == 0;
}
void setAlarmOutput(bool active) {
  alarmAsserted = active;
  if (!DRIVE_ALARM) return;
  // Open-drain behavior. Interface transistor required where pull-up exceeds
  // 3.3 V. HIGH is never driven onto the robot's ALARMB net.
  digitalWrite(ALARM_PIN, LOW);
  pinMode(ALARM_PIN, active ? OUTPUT : INPUT);
}
void setPower(bool on) {
  if (!DRIVE_POWER) return;
  digitalWrite(POWER_PIN, on ? POWER_ON_LEVEL : !POWER_ON_LEVEL);
  pinMode(POWER_PIN, OUTPUT);
}
void programAlarm() {
  if (!rtcPresent) return;
  const auto &s = protocol.state;
  // Alarm 1: daily HH:MM:00, date ignored. Alarm 2 is unused/disabled.
  uint8_t alarm[] = {0, bcd(s.alarmMinute), bcd(s.alarmHour), 0x80};
  uint8_t control, status;
  if (!readRTC(0x0e, &control, 1) || !readRTC(0x0f, &status, 1)) return;
  control = (control & ~0x83) | 0x04 | (s.alarmEnabled ? 1 : 0);
  status &= ~0x03;
  writeRTC(7, alarm, 4); writeRTC(0x0f, &status, 1);
  writeRTC(0x0e, &control, 1);
  setAlarmOutput(false);
}
void Events::changed() { dirty = true; }
void Events::command(uint8_t value) {
  if (value == 0xe6) setPower(true);
  if (value == 0xe7 || value == 0xe8) {
    uint8_t time[3];
    if (rtcPresent && readRTC(0, time, 3)) {
      if (value == 0xe7) time[1] = bcd((decimal(time[1] & 0x7f) + 1) % 60);
      if (value == 0xe8) time[2] = bcd((decodeHour(time[2]) + 1) % 24);
      writeRTC(0, time, 3);
    }
  }
  if (value == 0xe9 || value == 0xea || value == 0xeb || value == 0xee)
    programAlarm();
}
void clockEdge() {
  uint32_t now = micros();
  if (RECEIVE_GAP_US > 0 && uint32_t(now - lastEdge) > uint32_t(RECEIVE_GAP_US))
    receiver.reset();
  lastEdge = now;
  uint8_t byte;
  if (!receiver.sample(digitalRead(DATA_PIN), byte)) return;
  uint8_t next = producer + 1;
  if (next == consumer) { overflow = true; return; }
  queueBytes[producer] = byte;
  producer = next;
}
void centered(const char *text, int baseline) {
  int width = screen.getStrWidth(text);
  screen.drawStr(max(0, (256 - width) / 2), baseline, text);
}
void rawGlyph(uint8_t glyph, int x) {
  const uint8_t masks[] = {0x80, 0x40, 0x20, 0x10, 8, 4, 2};
  const int boxes[][4] = {{5,2,24,3},{29,5,3,16},{29,25,3,16},
                         {5,41,24,3},{2,25,3,16},{2,5,3,16},{5,21,24,3}};
  for (int i = 0; i < 7; ++i)
    if (glyph & masks[i]) screen.drawBox(x + boxes[i][0], boxes[i][1], boxes[i][2], boxes[i][3]);
  if (glyph & 1) screen.drawDisc(x + 37, 42, 2);
}
void render() {
  auto &s = protocol.state;
  screen.clearBuffer();
  screen.setFont(u8g2_font_helvB12_tr);
  char text[40];
  switch (s.view) {
    case HeadState::Clock:
    case HeadState::Alarm:
      centered(s.view == HeadState::Clock ? "MAXX STEELE" : "ALARM TIME", 16);
      screen.setFont(u8g2_font_logisoso24_tn);
      if (s.view == HeadState::Clock && !rtcValid) snprintf(text, sizeof text, "--:--");
      else snprintf(text, sizeof text, "%02u:%02u", s.view == HeadState::Clock ? hourNow : s.alarmHour,
                     s.view == HeadState::Clock ? minuteNow : s.alarmMinute);
      centered(text, 46); break;
    case HeadState::Sleeping:
      centered("MAXX IS SLEEPING", 22);
      screen.setFont(u8g2_font_6x12_tr);
      if (s.alarmEnabled) snprintf(text, sizeof text, "Wake alarm %02u:%02u", s.alarmHour, s.alarmMinute);
      else snprintf(text, sizeof text, "Alarm off");
      centered(text, 42); break;
    case HeadState::MessageView: {
      const Message &m = messages[s.message];
      centered(m.title, 25);
      screen.setFont(u8g2_font_6x12_tr); centered(m.detail, 43); break;
    }
    case HeadState::Raw:
      for (int i = 0; i < 4; ++i) rawGlyph(s.glyphs[i], 34 + i * 48);
      break;
  }
  screen.drawHLine(0, 49, 256);
  screen.setFont(u8g2_font_6x12_tr);
  snprintf(text, sizeof text, "%s   ALARM %s%s", !rtcPresent ? "NO RTC" : rtcValid ? "MAXX" : "SET RTC",
           s.alarmEnabled ? "ON" : "OFF", alarmAsserted ? " *" : "");
  screen.drawStr(2, 62, text);
  screen.sendBuffer();
  dirty = false;
  // For e-paper, replace this renderer with one that waits for BUSY to clear
  // before this power action. Keep the head controller/RTC on an always-on rail.
  if (s.view == HeadState::Sleeping) setPower(false);
}
void pollRTC() {
  uint8_t time[3], status;
  bool ok = readRTC(0, time, 3) && readRTC(0x0f, &status, 1);
  rtcPresent = ok;
  rtcValid = ok && !(status & 0x80);
  if (!ok) return;
  uint8_t h = decodeHour(time[2]), m = decimal(time[1] & 0x7f);
  if (h != hourNow || m != minuteNow) dirty = true;
  hourNow = h; minuteNow = m;
  if ((status & 1) && protocol.state.alarmEnabled && !alarmAsserted) {
    setAlarmOutput(true); setPower(true);
    protocol.state.view = HeadState::Clock; dirty = true;
    // Leave A1F latched until the CPU's EE acknowledgement.
  }
}
void setTimeFromUSB(const char *digits) {
  unsigned year, month, day, hour, minute, second;
  if (sscanf(digits, "%4u%2u%2u%2u%2u%2u", &year, &month, &day, &hour, &minute, &second) != 6) return;
  const uint8_t monthDays[] = {31,28,31,30,31,30,31,31,30,31,30,31};
  if (year < 2000 || year > 2099 || month < 1 || month > 12 || day < 1 ||
      day > unsigned(monthDays[month-1] + (month == 2 && year % 4 == 0)) ||
      hour > 23 || minute > 59 || second > 59) {
    Serial.println("Invalid timestamp"); return;
  }
  uint8_t time[] = {bcd(second), bcd(minute), bcd(hour), 1, bcd(day), bcd(month), bcd(year-2000)};
  uint8_t status;
  if (writeRTC(0, time, 7) && readRTC(0x0f, &status, 1)) {
    status &= ~0x80; writeRTC(0x0f, &status, 1);
    Serial.println("RTC set"); dirty = true;
  } else Serial.println("RTC write failed");
}
void setup() {
  Serial.begin(115200);
  pinMode(DATA_PIN, INPUT); pinMode(CLOCK_PIN, INPUT); pinMode(ALARM_PIN, INPUT);
  Wire.setSDA(RTC_SDA); Wire.setSCL(RTC_SCL); Wire.begin();
  uint8_t alarm[4], control;
  rtcPresent = readRTC(7, alarm, 4) && readRTC(0x0e, &control, 1);
  if (rtcPresent) {
    protocol.state.alarmHour = decodeHour(alarm[2]);
    protocol.state.alarmMinute = decimal(alarm[1] & 0x7f);
    if (protocol.state.alarmHour > 23) protocol.state.alarmHour = 7;
    if (protocol.state.alarmMinute > 59) protocol.state.alarmMinute = 0;
    protocol.state.alarmEnabled = control & 1;
  }
  screen.begin(); setPower(true);
  static_assert(RECEIVE_SPI_MODE < 4, "SPI mode must be 0..3");
  bool rising = (RECEIVE_SPI_MODE == 0 || RECEIVE_SPI_MODE == 3) ^ INVERT_CLOCK;
  attachInterrupt(digitalPinToInterrupt(CLOCK_PIN), clockEdge, rising ? RISING : FALLING);
  Serial.println("Maxx head: n=next message, c=clock, a=alarm, s=sleep, w=wake, r=resync");
  Serial.println("Set RTC: TYYYYMMDDhhmmss (24-hour time)");
}
void loop() {
  noInterrupts();
  bool lost = overflow;
  if (lost) { consumer = producer; overflow = false; receiver.reset(); }
  interrupts();
  if (lost) { protocol.resetFraming(); Serial.println("RX OVERFLOW: resync required"); }
  while (consumer != producer) {
    uint8_t byte = queueBytes[consumer]; ++consumer;
    protocol.feed(byte);
  }
  if (Serial.available()) {
    static uint8_t demo = 0;
    static char timestamp[15];
    static int timestampCount = -1;
    char input = Serial.read();
    if (input == 'T') timestampCount = 0;
    else if (timestampCount >= 0) {
      if (input >= '0' && input <= '9') {
        timestamp[timestampCount++] = input;
        if (timestampCount == 14) {
          timestamp[14] = 0; setTimeFromUSB(timestamp); timestampCount = -1;
        }
      } else { timestampCount = -1; Serial.println("Timestamp cancelled"); }
    } else switch (input) {
      case 'n':
        protocol.feed(0xe3); protocol.feed(0xf3);
        for (uint8_t glyph : messages[demo].glyphs) protocol.feed(glyph);
        protocol.feed(0xe2); demo = (demo + 1) % 32; break;
      case 'c': protocol.feed(0xe0); break;
      case 'a': protocol.feed(0xe1); break;
      case 's': protocol.feed(0xe5); break;
      case 'w': protocol.feed(0xe6); break;
      case 'r':
        noInterrupts(); receiver.reset(); consumer = producer; overflow = false; interrupts();
        protocol.resetFraming(); Serial.println("RX reset; next edge is bit 7"); break;
    }
  }
  if (uint32_t(millis() - lastPoll) >= 250) { lastPoll = millis(); pollRTC(); }
  if (dirty) render();
}
