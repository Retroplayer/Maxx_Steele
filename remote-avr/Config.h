#pragma once
#include <stdint.h>
#ifndef F_CPU
#define F_CPU 8000000UL
#endif
static_assert(F_CPU == 8000000UL, "Timer/UART configuration requires 8 MHz");
namespace Config {
constexpr uint16_t SYMBOL_US = 1578;
constexpr uint16_t PERIOD_US = 28928;
constexpr uint32_t SLEEP_MS = 120000; // Configurable; original timeout unmeasured.
constexpr uint16_t DEBOUNCE_MS = 15;
constexpr uint16_t RF_SETTLE_MS = 20; // Verify with the retained transmitter.
constexpr uint16_t PC_LEASE_MS = 2000;
// Logical receiver symbol -> transistor BASE level. Q703 then inverts it.
// RF modulator/receiver may add inversion: determine end-to-end on the bench.
constexpr bool INVERT_DATA = false;
constexpr bool RF_ENABLE_HIGH = true;
constexpr bool LED_ON_HIGH = true;
}
