// Bare ATmega328P, avr-libc; no Arduino core or dynamic allocation.
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>
#include <avr/power.h>
#include <avr/pgmspace.h>
#include <avr/wdt.h>
#include <util/atomic.h>
#include <util/delay.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include "Remote.h"

// PORTC 0..5: rows D0,D1,L0,L1,L2,L3. PORTB 0..3: columns L7,L6,L5,L4.
// PD0/1 UART, PD2 STOP, PD4 RF enable, PD5 LED, PB4 modulation/base driver.
static volatile uint32_t ticks;
static volatile bool transmitting;
static volatile uint8_t symbolIndex;
static volatile uint16_t frameBits;
static volatile uint8_t rxHead,rxTail;
static volatile bool rxFault;
static volatile char rx[64];
static Remote::Controller controller;
static uint32_t lastActivity;
static uint32_t rfStarted;
static bool rfOn;
static uint32_t nowMS() { uint32_t n; ATOMIC_BLOCK(ATOMIC_RESTORESTATE) { n=ticks; } return n; }
static void data(bool logical) {
  if (logical ^ Config::INVERT_DATA) PORTB|=_BV(PB4); else PORTB&=~_BV(PB4);
}
ISR(TIMER0_COMPA_vect) { ++ticks; }
ISR(TIMER1_COMPA_vect) {
  if (symbolIndex<11) {
    data((frameBits>>(10-symbolIndex))&1); ++symbolIndex;
    OCR1A=Config::SYMBOL_US-1;
  } else if (symbolIndex==11) {
    data(false); ++symbolIndex;
    OCR1A=Config::PERIOD_US-11*Config::SYMBOL_US-1;
  } else {
    TCCR1B=0; TIMSK1=0; transmitting=false;
  }
}
ISR(USART_RX_vect) {
  uint8_t status=UCSR0A; char c=UDR0;
  uint8_t next=(rxHead+1)&63;
  if ((status&(_BV(FE0)|_BV(DOR0)|_BV(UPE0))) || next==rxTail) rxFault=true;
  else { rx[rxHead]=c; rxHead=next; }
}
ISR(INT0_vect) { EIMSK=0; }
ISR(PCINT2_vect) {} // RX edge wakes; first UART characters are disposable.
static void put(char c) { while (!(UCSR0A&_BV(UDRE0))) {} UCSR0A|=_BV(TXC0); UDR0=c; }
static void say(PGM_P p) { char c; while ((c=pgm_read_byte(p++))) put(c); }
#define SAY(s) say(PSTR(s))
static void number(uint32_t n) { char b[11]; ultoa(n,b,10); for(char *p=b;*p;++p) put(*p); }
static void led(bool on) {
  if (on==Config::LED_ON_HIGH) PORTD|=_BV(PD5); else PORTD&=~_BV(PD5);
}
static void radio(bool on) {
  if (on==Config::RF_ENABLE_HIGH) PORTD|=_BV(PD4); else PORTD&=~_BV(PD4);
  if (on&&!rfOn) rfStarted=nowMS();
  rfOn=on;
}
static void send(const Remote::Frame &f) {
  ATOMIC_BLOCK(ATOMIC_RESTORESTATE) {
    frameBits=Remote::symbols(Remote::encode(f.key,f.release));
    symbolIndex=1; transmitting=true;
    data((frameBits>>10)&1);
    TCCR1A=0; TCCR1B=0; TCNT1=0; OCR1A=Config::SYMBOL_US-1;
    TIFR1=_BV(OCF1A); TIMSK1=_BV(OCIE1A);
    TCCR1B=_BV(WGM12)|_BV(CS11); // 8 MHz / 8 = 1 us; CTC.
  }
}
static uint32_t scan() {
  uint32_t keys=0;
  for (uint8_t row=0;row<6;++row) {
    DDRC=0; PORTC=0; DDRC=_BV(row); // Selected output low; others floating.
    _delay_us(10);
    keys|=uint32_t((~PINB)&15)<<(row*4);
  }
  DDRC=0; return keys;
}
// Canonical names use the existing Pico remote's naming/ID order.
static const char names[][10] PROGMEM={
 "0","1","2","3","4","5","6","7","8","9","LAMP","HOME",
 "WAIT","OCTAVE","CLEAR","ENTER","SONG","CLOCK","SPEECH","MOTION",
 "GAME","PROGRAM","LEARN","EXECUTE","POWER"};
static uint8_t keyID(const char *s) {
  for(uint8_t i=0;i<25;++i) if (!strcmp_P(s,names[i])) return i+1;
  if (s[0]>='A'&&s[0]<='Y'&&!s[1]) return s[0]-'A'+1;
  if (!strcmp_P(s,PSTR("STOP"))) return 25;
  return 0;
}
static bool eq(const char *s,PGM_P p) { return !strcmp_P(s,p); }
#define EQ(s,v) eq(s,PSTR(v))
static bool command(char *line,uint32_t now) {
  char *op=strtok(line," \t"), *key=strtok(nullptr," \t");
  char *arg=strtok(nullptr," \t"), *extra=strtok(nullptr," \t");
  if (!op) return false;
  if (EQ(op,"DOWN")||EQ(op,"UP")||EQ(op,"TAP")) {
    if (!key || extra || (arg&&!EQ(op,"TAP"))) return false;
    uint8_t id=keyID(key); if (!id) return false;
    uint16_t duration=100;
    if (arg) {
      for(char *p=arg;*p;++p) if (!isdigit(*p)) return false;
      unsigned long value=strtoul(arg,nullptr,10);
      // Taps are bounded by the PC disconnect lease, not a separate long hold.
      if (value<60||value>1500) return false;
      duration=value;
    }
    if (id==25) { if (!EQ(op,"UP")) controller.stop(); }
    else if (EQ(op,"UP")) controller.up(id);
    else if (!controller.down(id,now,EQ(op,"TAP")?duration:0)) return false;
  } else {
    if (key) return false;
    if (EQ(op,"STOP")) controller.stop();
    else if (EQ(op,"PING")) {}
    else if (EQ(op,"STATUS")) {
      SAY("ACTIVE="); number(controller.active());
      SAY(" PC="); number(controller.pc()); SAY("\r\n");
    } else if (EQ(op,"KEYS")) {
      for(uint8_t i=0;i<25;++i) { put('A'+i); put('='); say(names[i]); put(' '); }
      SAY("\r\n");
    } else if (EQ(op,"HELP")) {
      SAY("PING STATUS KEYS STOP DOWN key UP key TAP key [60..1500 ms]\r\n");
    } else return false;
  }
  controller.contact(now); lastActivity=now; return true;
}
static char line[48];
static uint8_t lineLen;
static bool discard;
static uint32_t lastByte;
static void serial(uint32_t now) {
  // Abandoned partial lines must not prevent battery-saving sleep forever.
  if ((lineLen||discard) && uint32_t(now-lastByte)>=1000) { lineLen=0; discard=false; }
  bool fault;
  ATOMIC_BLOCK(ATOMIC_RESTORESTATE) { fault=rxFault; rxFault=false; }
  if (fault) { controller.stop(); discard=true; lineLen=0; }
  for(uint8_t work=0;work<16&&rxTail!=rxHead;++work) {
    char c=rx[rxTail]; rxTail=(rxTail+1)&63; lastByte=now;
    if(c=='\r') continue;
    if(c=='\n') {
      if(discard) SAY("ERR overflow or UART error\r\n");
      else if(lineLen) {
        line[lineLen]=0;
        if(command(line,now)) SAY("OK\r\n"); else SAY("ERR command/key/busy\r\n");
      }
      lineLen=0; discard=false;
    } else if(!discard) {
      if(lineLen<sizeof(line)-1) line[lineLen++]=toupper((unsigned char)c);
      else { discard=true; lineLen=0; controller.stop(); }
    }
  }
}
static void sleepUntilInput() {
  // Caller ensures no held button, pending frame, or unfinished input line.
  SAY("SLEEP\r\n");
  while(!(UCSR0A&_BV(TXC0))) {}
  cli();
  // Recheck after draining serial output; don't lose a concurrent button/byte.
  if (!(PIND&_BV(PD2)) || !(PIND&_BV(PD0)) || rxHead!=rxTail || rxFault) { sei(); return; }
  radio(false); data(false); led(false);
  UCSR0B=0; // Power-down cannot receive a complete UART byte.
  EICRA=0; EIFR=_BV(INTF0); EIMSK=_BV(INT0); // Low-level wake on STOP.
  PCIFR=_BV(PCIF2); PCMSK2=_BV(PCINT16); PCICR=_BV(PCIE2);
  set_sleep_mode(SLEEP_MODE_PWR_DOWN); sleep_enable();
  sleep_bod_disable();
  sei(); sleep_cpu(); sleep_disable();
  cli(); EIMSK=0; PCICR=0; PCMSK2=0;
  // Flush the partial wake preamble and any stale hardware receive byte.
  while(UCSR0A&_BV(RXC0)) { volatile uint8_t ignored=UDR0; (void)ignored; }
  rxHead=rxTail=0; lineLen=0; discard=false;
  UCSR0B=_BV(RXEN0)|_BV(TXEN0)|_BV(RXCIE0);
  sei(); led(true); lastActivity=nowMS();
  SAY("AWAKE\r\n");
}
int main() {
  MCUSR=0; wdt_disable(); clock_prescale_set(clock_div_1);
  ADCSRA=0; ACSR=_BV(ACD); power_adc_disable(); power_spi_disable(); power_twi_disable();
  // Establish safe output latches before changing direction.
  data(false); radio(false); led(false);
  DDRB=_BV(PB4); PORTB|=uint8_t(~_BV(PB4)); // Four pulled-up column inputs.
  DDRC=0; PORTC=0;
  DDRD=_BV(PD1)|_BV(PD4)|_BV(PD5); PORTD|=_BV(PD2)|_BV(PD0)|_BV(PD3)|_BV(PD6)|_BV(PD7);
  UCSR0A=_BV(U2X0)|_BV(TXC0); UBRR0=25; // 38400 baud, 0.16% nominal error.
  UCSR0C=_BV(UCSZ01)|_BV(UCSZ00); UCSR0B=_BV(RXEN0)|_BV(TXEN0)|_BV(RXCIE0);
  TCCR0A=_BV(WGM01); OCR0A=124; TCCR0B=_BV(CS01)|_BV(CS00); TIMSK0=_BV(OCIE0A);
  sei(); led(true); SAY("MAXX AVR REMOTE 1 READY 38400\r\n");
  Remote::Debouncer keyboard,stopButton;
  uint32_t lastKeys=0; bool lastStop=false, ghostLatched=false;
  uint32_t lastScan=0;
  for(;;) {
    uint32_t now=nowMS();
    serial(now); controller.advance(now);
    if(uint32_t(now-lastScan)>=5) {
      lastScan=now;
      uint32_t keys=keyboard.update(scan(),now);
      bool stop=stopButton.update(!(PIND&_BV(PD2)),now)!=0;
      if(keys || stop) lastActivity=now;
      bool ghost=Remote::ambiguous(keys);
      if(ghost&&!ghostLatched) controller.stop();
      ghostLatched=ghost;
      if(keys!=lastKeys || ghost || stop) {
        controller.physical(keys,ghost||stop); // Hold ambiguous/STOP-suppressed keys off until released.
        lastKeys=keys;
      }
      if(stop&&!lastStop) controller.stop();
      lastStop=stop;
    }
    bool demand=controller.active()||controller.pending();
    if(demand&&!rfOn) radio(true);
    if(!transmitting && rfOn && uint32_t(now-rfStarted)>=Config::RF_SETTLE_MS) {
      Remote::Frame frame;
      if(controller.next(frame)) send(frame);
    }
    // Keep transmitter powered while awake; only gate it during deep sleep.
    if(!transmitting && !controller.active() && !controller.pending() &&
       !lastKeys && !lastStop && !lineLen && !discard &&
       uint32_t(now-lastActivity)>=Config::SLEEP_MS) sleepUntilInput();
  }
}
