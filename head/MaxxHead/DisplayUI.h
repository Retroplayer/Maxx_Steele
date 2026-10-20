#pragma once
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "Messages.h"

// Inference from the stock display stream only: no remote key interception.
// Value changes are not treated as ENTER, nor counted as stored program steps.
class DisplayUI {
 public:
  enum Mode { Unknown, Immediate, Learn, Program, Execute, Game } mode = Unknown;
  enum Activity { None, Song, Sound, Sentence, Settings, Music, SpeechEditor } activity = None;
  enum Layout { Announcement, Entry, Segments, Scores } layout = Announcement;
  char title[40] = {}, value[40] = {}, footer[40] = {};
  int step = -1, phrase = -1, game = -1;
  int playerScore = 0, maxxScore = 0;

  void reset() {
    mode = Unknown; activity = None; layout = Segments;
    step = phrase = game = -1;
    gamePhase = 0; gameCandidate = -1; moonScoreSeen = false;
    title[0] = value[0] = 0; updateFooter();
  }
  void command(uint8_t byte) {
    if (byte == 0xe0 || byte == 0xe6) {
      reset(); mode = Immediate; updateFooter();
    }
  }
  void frame(const uint8_t *glyphs, int preset) {
    title[0] = value[0] = 0;
    if (preset >= 0) {
      layout = Announcement;
      snprintf(title, sizeof title, "%s", messages[preset].title);
      snprintf(value, sizeof value, "%s", messages[preset].detail);
      if (preset >= 6 && preset <= 9) {
        reset(); mode = static_cast<Mode>(Learn + preset - 6);
        layout = Announcement;
        snprintf(title, sizeof title, "%s", messages[preset].title);
        if (mode == Game) {
          gamePhase = 0;
          snprintf(value, sizeof value, "0 Moon Ball / 1 Force Field");
        }
      } else switch (preset) {
        case 0: activity = Song; break;
        case 1: activity = Sound; break;
        case 2: activity = Sentence; break;
        case 3: activity = Settings; break;
        case 4: activity = Music; break;
        case 5: activity = None; mode = Immediate; break;
        default: break; // Errors, bEg/End and settings never overwrite mode.
      }
      updateFooter(); return;
    }
    if (mode == Game && gameFrame(glyphs)) { updateFooter(); return; }
    if ((activity == Music || activity == Song) && musicFrame(glyphs)) {
      activity = Music; updateFooter(); return;
    }
    if (commandFrame(glyphs)) { updateFooter(); return; }
    int number = 0; bool missing = false;
    if (digits(glyphs, 4, number, missing) && !missing) {
      layout = Entry;
      if ((mode == Program || mode == Learn) && activity == None && glyphs[0] == 0) {
        step = number;
        snprintf(title, sizeof title, "Program step");
        snprintf(value, sizeof value, "%03d", number);
      } else {
        snprintf(title, sizeof title, "Value");
        snprintf(value, sizeof value, "%d", number);
      }
    } else {
      layout = Segments; snprintf(title, sizeof title, "Original display");
    }
    updateFooter();
  }
  static int digit(uint8_t glyph) {
    static const uint8_t masks[] = {0xfc,0x60,0xda,0xf2,0x66,0xb6,0xbe,0xe0,0xfe,0xe6};
    for (int i=0; i<10; ++i) if (glyph == masks[i]) return i;
    return -1;
  }
 private:
  int gamePhase = 0, gameCandidate = -1;
  bool moonScoreSeen = false;
  static bool digits(const uint8_t *g, int length, int &number, bool &missing) {
    number = 0; missing = false;
    bool started = false, placeholders = false;
    for (int i=0; i<length; ++i) {
      if (g[i] == 0x10) { placeholders = true; missing = true; continue; }
      if (g[i] == 0 && !started && !placeholders) continue;
      int d = digit(g[i]);
      if (d < 0 || placeholders) return false;
      started = true; number = number * 10 + d;
    }
    return started || missing;
  }
  bool commandFrame(const uint8_t *g) {
    struct Command { uint8_t prefix[3]; uint8_t length, fixedBlank;
                     const char *label; };
    // Exact stock prefixes from $F878/$F889/$F897, checked against executed
    // $F668/$F66C routines. Underscores are prompts, not a numerical zero.
    static const Command commands[] = {
      {{0x1c,0,0},1,1,"Turn left"}, {{0x8e,0,0},1,0,"Forward"},
      {{0x3e,0,0},1,0,"Backward"}, {{0x0a,0,0},1,1,"Turn right"},
      {{0x7c,0x38,0},2,0,"Wrist up"}, {{0x7c,0x7a,0},2,0,"Wrist down"},
      {{0xee,0x38,0},2,0,"Arms up"}, {{0xee,0x7a,0},2,0,"Arms down"},
      {{0x9c,0x0a,0},2,0,"Rotate claw"}, {{0x9c,0x1a,0x3a},3,0,"Claw"},
      {{0x6e,0x1c,0},2,1,"Headlamp"}, {{0x7a,0,0},1,0,"Wait"},
      {{0xb6,0x2a,0},2,1,"Song"}, {{0xb6,0xb6,0},2,0,"Sentence"},
      {{0xce,0xb6,0},2,0,"Edit sentence"}, {{0xb6,0,0},1,0,"Speech code"},
    };
    for (unsigned i=0; i<sizeof commands/sizeof commands[0]; ++i) {
      const Command &c = commands[i];
      if (memcmp(g, c.prefix, c.length)) continue;
      if (c.fixedBlank && g[c.length] != 0) continue;
      const int start = c.length + c.fixedBlank;
      int number; bool missing;
      if (!digits(g+start, 4-start, number, missing)) continue;
      // Accept only complete known numeric/prompt grammar; preserve unknowns.
      if (i == 14) { activity = SpeechEditor; if (!missing) phrase = number; }
      else if (i == 12 && activity != SpeechEditor) activity = Song;
      else if (i == 13 && activity != SpeechEditor) activity = Sentence;
      else if (i == 15 && activity != SpeechEditor) activity = Sound;
      else if (i < 12) activity = None;
      layout = Entry;
      snprintf(title, sizeof title, "%s", i == 15 && activity == SpeechEditor ? "Word code" : c.label);
      if (missing) snprintf(value, sizeof value, "Enter value");
      else if (i == 9 && number <= 1) snprintf(value, sizeof value, "%s", number ? "Close" : "Open");
      else if (i == 10 && number <= 1) snprintf(value, sizeof value, "%s", number ? "On" : "Off");
      else if (i == 11) snprintf(value, sizeof value, "%d seconds", number);
      else if (i == 15 && number == 140) snprintf(value, sizeof value, "140  Pause");
      else snprintf(value, sizeof value, "%d", number);
      return true;
    }
    return false;
  }
  bool musicFrame(const uint8_t *g) {
    int tens = digit(g[0] & 0xfe), ones = digit(g[1] & 0xfe);
    if (tens < 0 || ones < 0) return false;
    static const uint8_t pitches[] = {0x3e,0x9c,0x9d,0x7a,0x7b,0x9e,0x8e,0x8f,0xf6,0xf7,0xee,0xef};
    static const char *names[] = {"B","C","C#","D","D#","E","F","F#","G","G#","A","A#"};
    const char *pitch = nullptr;
    for (int i=0; i<12; ++i) if (g[2] == pitches[i]) pitch = names[i];
    if (g[2] == 0x0a) pitch = "Rest";
    if (g[2] == 0x10) pitch = "--";
    if (!pitch || ((g[1] & 1) != (g[2] & 1))) return false;
    int duration = digit(g[3]);
    if (duration < 0 && g[3] != 0x10) return false;
    layout = Entry;
    snprintf(title, sizeof title, "Note %02d / %s octave", tens*10+ones, (g[0]&1) ? "shifted" : "normal");
    if (g[3] == 0x10) snprintf(value, sizeof value, "%s  Duration --", pitch);
    else snprintf(value, sizeof value, "%s  Duration %d", pitch, duration);
    return true;
  }
  bool gameFrame(const uint8_t *g) {
    int number; bool missing;
    if (!digits(g, 4, number, missing)) return false;
    layout = Entry;
    bool prompt = g[0]==0 && g[1]==0 && g[2]==0 && g[3]==0x10;
    if (prompt) {
      if (gamePhase == 0 && gameCandidate >= 0 && gameCandidate <= 1) {
        game = gameCandidate; gamePhase = 1;
      }
      snprintf(title, sizeof title, "%s", gamePhase == 0 ? "Choose game" : "Game setup");
      snprintf(value, sizeof value, "%s", gamePhase == 0 ? "0 Moon / 1 Force" : "Difficulty 0-3");
      return true;
    }
    if (missing) return false;
    if (gamePhase == 0 && g[0]==0 && g[1]==0 && g[2]==0) {
      gameCandidate = number;
      snprintf(title, sizeof title, "Game choice");
      snprintf(value, sizeof value, "%d", number); return true;
    }
    if (game == 1 && digit(g[0]) >= 0 && digit(g[1]) >= 0 &&
        digit(g[2]) >= 0 && digit(g[3]) >= 0) {
      layout = Scores; playerScore = number/100; maxxScore = number%100;
      snprintf(title, sizeof title, "Force Field");
      snprintf(value, sizeof value, "%02d       %02d", playerScore, maxxScore);
    } else {
      if (game == 0 && number > 3) moonScoreSeen = true;
      snprintf(title, sizeof title, "%s", game == 0 && moonScoreSeen ? "Score" : "Game value");
      snprintf(value, sizeof value, "%d", number);
    }
    return true;
  }
  void updateFooter() {
    static const char *modes[] = {"MAXX", "IMMEDIATE", "LEARN", "PROGRAM", "EXECUTE", "GAME"};
    const char *activityText = "";
    switch (activity) {
      case Song: activityText = "SONG"; break;
      case Sound: activityText = "SPEECH"; break;
      case Sentence: activityText = "SENTENCE"; break;
      case Settings: activityText = "SETTINGS"; break;
      case Music: activityText = "MUSIC"; break;
      case SpeechEditor: activityText = "SPEECH EDIT"; break;
      default: break;
    }
    if (mode == Game && game >= 0)
      snprintf(footer, sizeof footer, "GAME | %s", game == 0 ? "MOON BALL" : "FORCE FIELD");
    else if (activity == SpeechEditor && phrase >= 0)
      snprintf(footer, sizeof footer, "%s | SENTENCE %d", modes[mode], phrase);
    else if (*activityText)
      snprintf(footer, sizeof footer, "%s | %s", modes[mode], activityText);
    else if ((mode == Program || mode == Learn) && step >= 0)
      snprintf(footer, sizeof footer, "%s | STEP %03d", modes[mode], step);
    else snprintf(footer, sizeof footer, "%s", modes[mode]);
  }
};
