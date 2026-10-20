/* Maxx / original STM32F405 KFF bench experiment. Standalone firmware. */
#include <stdint.h>
#define REG(a) (*(volatile uint32_t *)(a))
#define RCC 0x40023800u
#define GPIOA 0x40020000u
#define GPIOB 0x40020400u
#define GPIOC 0x40020800u
#define IDR 0x10u
#define WRB (1u << 0)
#define OEB (1u << 8)
#define DATA_MODE (*(volatile uint16_t *)GPIOC)
#define DATA_OUT (*(volatile uint8_t *)(GPIOC + 0x14))
extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss;
extern uint32_t _siram, _sram, _eram;
static uint8_t image[8192] __attribute__((aligned(4)));
#include "image.h"
static void clocks(void) {
    REG(RCC+0x40) |= 1u<<28; (void)REG(RCC+0x40); /* PWR clock */
    REG(0x40007000) |= 1u<<14; /* voltage scale 1 */
    REG(RCC) |= 1u<<16; /* original KFF 8MHz crystal */
    while (!(REG(RCC)&(1u<<17))) {} /* Fail with bus still input. */
    REG(RCC+8) = (5u<<10)|(4u<<13); /* APB1 /4, APB2 /2 */
    REG(RCC+4) = 8u|(336u<<6)|(1u<<22)|(7u<<24); /* PLL 168MHz */
    REG(0x40023c00) = 5u|(7u<<8); /* flash 5WS, prefetch and caches */
    REG(RCC) |= 1u<<24;
    while (!(REG(RCC)&(1u<<25))) {}
    REG(RCC+8) |= 2u;
    while ((REG(RCC+8)&12u)!=8u) {}
}
/* SRAM-resident loop. No interrupts, flash writes, USB or SD activity.
 * Assumes OEB low + WRB high qualifies a read with stable address.
 * Release on strobe end, write or address change. Requires timing validation.
 */
__attribute__((section(".ramcode"),noreturn,noinline))
static void serve(void) {
    for (;;) {
        uint32_t control=REG(GPIOA+IDR);
        if ((control&(OEB|WRB))!=WRB) continue;
        uint32_t address=REG(GPIOB+IDR)&0xffffu;
        if ((address&0xe000u)!=0xa000u) continue;
        uint32_t value=image[address&0x1fffu];
        DATA_OUT=value; /* preload before changing direction */
        if ((REG(GPIOA+IDR)&(OEB|WRB))!=WRB ||
            (REG(GPIOB+IDR)&0xffffu)!=address) continue;
        DATA_MODE=0x5555u;
        while ((REG(GPIOA+IDR)&(OEB|WRB))==WRB &&
               (REG(GPIOB+IDR)&0xffffu)==address) {}
        DATA_MODE=0;
    }
}
void Reset_Handler(void) {
    __asm volatile("cpsid i");
    uint32_t *s=&_sidata;
    for(uint32_t *d=&_sdata;d<&_edata;) *d++=*s++;
    s=&_siram;
    for(uint32_t *d=&_sram;d<&_eram;) *d++=*s++;
    for(uint32_t *d=&_sbss;d<&_ebss;) *d++=0;
    REG(RCC+0x30)|=7u; (void)REG(RCC+0x30);
    REG(GPIOB)=0; REG(GPIOB+0x0c)=0;
    DATA_MODE=0; REG(GPIOC+0x0c)&=~0xffffu;
    /* PC12 reset driver, PC14/15 and other C64 controls remain inputs.
       Keep PA13/14 SWD. External harness pull-ups on PA0 and PA8. */
    REG(GPIOA)&=~((3u<<0)|(3u<<16));
    REG(GPIOA+0x0c)&=~((3u<<0)|(3u<<16));
    REG(GPIOC+8)|=0xffffu; /* very high speed PC0..7 */
    clocks();
    for(uint32_t i=0;i<sizeof image;i++) image[i]=boot_image[i];
    REG(GPIOC+0x18)=1u<<(13+16); /* LED active low */
    REG(GPIOC)=(REG(GPIOC)&~(3u<<26))|(1u<<26);
    __asm volatile("dsb\n isb" ::: "memory");
    serve();
}
void Fault_Handler(void) {
    DATA_MODE=0;
    for(;;) {}
}
