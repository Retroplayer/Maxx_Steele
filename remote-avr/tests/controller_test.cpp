#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../Remote.h"
using namespace Remote;
static void frame(Controller &c,uint8_t id,bool release=false) {
  Frame f;
  assert(c.next(f));
  if(f.key!=id || f.release!=release)
    fprintf(stderr,"expected %u/%u got %u/%u\n",id,release,f.key,f.release);
  assert(f.key==id && f.release==release);
}
int main(int argc,char **argv) {
  if(argc==2&&!strcmp(argv[1],"--frames")) {
    for(uint8_t i=1;i<=25;++i) for(uint8_t r=0;r<2;++r)
      printf("%u %u %u %u\n",i,r,encode(i,r),symbols(encode(i,r)));
    return 0;
  }
  assert(encode(1,false)==0x41 && symbols(0x41)==0x545);
  assert(encode(25,false)==0xd9 && encode(25,true)==0x39);
  Controller c; Frame f;
  c.physical(1); frame(c,1); frame(c,1);
  c.physical(3); frame(c,2);
  assert(c.next(f)); uint8_t first=f.key; assert(!f.release);
  assert(c.next(f)); assert(!f.release && f.key!=first);
  c.physical(2); frame(c,1,true); frame(c,2);
  c.physical(0); frame(c,2,true); assert(!c.next(f));
  assert(c.down(3,0)); c.physical(4); frame(c,3);
  c.up(3); frame(c,3); c.physical(0); frame(c,3,true);
  c.physical(3); frame(c,1); frame(c,2);
  assert(!c.down(3,10)); c.physical(7); frame(c,25);
  c.physical(3); assert(!c.next(f)); c.physical(0);
  c.physical(1); frame(c,1); c.stop(); frame(c,25);
  c.physical(1); assert(!c.next(f)); c.physical(0);
  c.physical(1); frame(c,1); c.physical(2); frame(c,1,true); frame(c,2);
  c.physical(0); frame(c,2,true);
  assert(c.down(4,100,100)); frame(c,4); c.advance(199); frame(c,4);
  c.advance(200); frame(c,4,true);
  assert(c.down(5,0)); frame(c,5); c.contact(1900); c.advance(2000); frame(c,5);
  c.advance(3900); frame(c,25); assert(!c.next(f));
  assert(c.down(6,0xfffffff0UL,100)); frame(c,6);
  c.advance(0x53); frame(c,6); c.advance(0x54); frame(c,6,true);
  assert(c.down(7,0xfffffff0UL)); c.advance(0x7c0); frame(c,25);
  assert(!c.down(0,0)&&!c.down(25,0));
  c.physical(0x33,true); assert(!c.next(f));
  c.physical(1); assert(!c.next(f)); // No unexpected restart after ghost clears.
  c.physical(0); c.physical(1); frame(c,1);
  c.physical(1,true); frame(c,1,true);
  c.physical(1); assert(!c.next(f));
  Debouncer d;
  assert(d.update(1,0)==0); assert(d.update(0,5)==0);
  assert(d.update(1,10)==0); assert(d.update(1,24)==0);
  assert(d.update(1,25)==1);
  assert(!ambiguous(3)); assert(!ambiguous(0x11));
  assert(ambiguous(0x13)); assert(ambiguous(0x33));
  puts("PASS: press/release/repeat, two-key limit, STOP inhibition, source ownership, tap/lease wraparound, debounce and ghost detection");
}
