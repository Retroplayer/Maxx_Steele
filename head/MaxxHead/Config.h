#pragma once
// Arduino-Pico core, Waveshare RP2040-Zero (Pico Zero).
// Numbers below are RP2040 GPIO numbers, not physical pad positions.
// Robot inputs MUST be translated to 3.3 V. GP16 drives the onboard RGB LED
// and is deliberately left unused.
constexpr int DATA_PIN = 0, CLOCK_PIN = 1;
constexpr int ALARM_PIN = 2, POWER_PIN = 3;
constexpr int RTC_SDA = 4, RTC_SCL = 5; // I2C0, exposed edge pads
constexpr int OLED_RESET = 6, OLED_DC = 7, OLED_CS = 9;
constexpr int OLED_CLOCK = 8, OLED_DATA = 10;
constexpr unsigned RECEIVE_SPI_MODE = 0; // 0..3; rising for 0/3, falling for 1/2
constexpr bool INVERT_CLOCK = false, INVERT_DATA = false, LSB_FIRST = false;
// Bring-up uses GPIO edge interrupts, not a hardware SPI slave. These settings
// select equivalent sampling edges; CPOL does not actively drive the input.
constexpr bool DRIVE_ALARM = false; // Enable after checking interface circuitry.
constexpr bool DRIVE_POWER = false; // Enable only after establishing power wiring.
constexpr bool POWER_ON_LEVEL = true;
// -1 disables gap reset. Byte/bit alignment then starts at the next 8 clocks
// after boot or USB 'r'. A measured timeout may be supplied for bench recovery.
constexpr int RECEIVE_GAP_US = -1;
