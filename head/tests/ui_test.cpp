#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../MaxxHead/Protocol.h"
struct Events : HeadEvents { void changed() override {} void command(uint8_t) override {} };
void frame(HeadProtocol &p, const uint8_t *g) {
  p.feed(0xe3); p.feed(0xf3);
  for (int i=0; i<4; ++i) p.feed(g[i]);
  p.feed(0xe2);
}
void preset(HeadProtocol &p, int n) { frame(p, messages[n].glyphs); }
int main(int argc, char **) {
  Events e; HeadProtocol p(e);
  if (argc > 1) {
    // Independent original-ROM fixture stream from check_head_ui.py.
    unsigned g[4]; char title[40];
    while (scanf("%x %x %x %x %39[^\n]", &g[0], &g[1], &g[2], &g[3], title) == 5) {
      p.resetFraming(); preset(p, 7);
      uint8_t glyphs[] = {uint8_t(g[0]),uint8_t(g[1]),uint8_t(g[2]),uint8_t(g[3])};
      frame(p, glyphs);
      if (strcmp(p.state.ui.title, title)) {
        fprintf(stderr,"%02x %02x %02x %02x expected '%s', got '%s'\n",
                g[0],g[1],g[2],g[3],title,p.state.ui.title); return 1;
      }
    }
    return 0;
  }
  preset(p,7);
  const uint8_t step0[] = {0,0xfc,0xfc,0xfc}; frame(p,step0);
  assert(!strcmp(p.state.ui.footer,"PROGRAM | STEP 000"));
  const uint8_t prompt[] = {0x8e,0x10,0x10,0x10}; frame(p,prompt);
  assert(!strcmp(p.state.ui.title,"Forward") && !strcmp(p.state.ui.value,"Enter value"));
  const uint8_t forward[] = {0x8e,0,0x60,0xda}; frame(p,forward);
  assert(!strcmp(p.state.ui.value,"12") && p.state.ui.step==0);
  preset(p,31); assert(!strcmp(p.state.ui.footer,"PROGRAM | STEP 000"));
  preset(p,12); assert(p.state.ui.mode==DisplayUI::Program);
  const uint8_t step1[] = {0,0xfc,0xfc,0x60}; frame(p,step1);
  assert(p.state.ui.step==1);
  const uint8_t ps[] = {0xce,0xb6,0x60,0xda}; frame(p,ps);
  const uint8_t sound[] = {0xb6,0,0xbe,0xb6}; frame(p,sound);
  assert(!strcmp(p.state.ui.title,"Word code") && !strcmp(p.state.ui.footer,"PROGRAM | SENTENCE 12"));
  preset(p,31); frame(p,sound); assert(p.state.ui.phrase==12);
  const uint8_t close[] = {0x9c,0x1a,0x3a,0x60}; frame(p,close);
  assert(!strcmp(p.state.ui.value,"Close"));
  const uint8_t open[] = {0x9c,0x1a,0x3a,0xfc}; frame(p,open);
  assert(!strcmp(p.state.ui.value,"Open"));
  preset(p,7); preset(p,0);
  const uint8_t note[] = {0xfd,0xfc,0x8e,0xf2}; frame(p,note);
  assert(p.state.ui.activity==DisplayUI::Music);
  assert(!strcmp(p.state.ui.title,"Note 00 / shifted octave"));
  assert(!strcmp(p.state.ui.value,"F  Duration 3"));
  preset(p,12); assert(!strcmp(p.state.ui.footer,"PROGRAM | MUSIC"));
  preset(p,9);
  const uint8_t choose[] = {0,0,0,0x10}; frame(p,choose);
  const uint8_t one[] = {0,0,0,0x60}; frame(p,one); frame(p,choose);
  assert(p.state.ui.game==1);
  frame(p,one); assert(!strcmp(p.state.ui.title,"Game value"));
  const uint8_t score[] = {0x60,0xb6,0xfc,0x66}; frame(p,score);
  assert(p.state.ui.layout==DisplayUI::Scores && p.state.ui.playerScore==15 && p.state.ui.maxxScore==4);
  frame(p,one); assert(!strcmp(p.state.ui.title,"Game value")); // Intermission level, not 00:01 score.
  preset(p,9); frame(p,choose);
  const uint8_t zero[] = {0,0,0,0xfc}; frame(p,zero); frame(p,choose);
  frame(p,one); assert(!strcmp(p.state.ui.title,"Game value")); // Setup vs initial low score ambiguous.
  const uint8_t five[] = {0,0,0,0xb6}; frame(p,five);
  assert(!strcmp(p.state.ui.title,"Score"));
  const uint8_t unknown[] = {0x99,0x89,0x79,0x69}; frame(p,unknown);
  assert(p.state.ui.layout==DisplayUI::Segments && p.state.ui.mode==DisplayUI::Game);
  p.feed(0xe0); assert(p.state.ui.mode==DisplayUI::Immediate && p.state.ui.game==-1);
  preset(p,6); p.resetFraming(); assert(p.state.ui.mode==DisplayUI::Unknown);
  puts("PASS: program entry, persistent modes/errors, speech editing, music, game setup/scores, ambiguous/raw fallback, resync");
}
