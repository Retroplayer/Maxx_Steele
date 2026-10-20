MCU = atmega328p
CXX = avr-g++
OBJCOPY = avr-objcopy
SIZE = avr-size
CXXFLAGS = -mmcu=$(MCU) -DF_CPU=8000000UL -std=gnu++11 -Os -Wall -Wextra -Werror -ffunction-sections -fdata-sections
all: build/remote.hex
build/remote.elf: main.cpp Remote.h Config.h
	mkdir -p build
	$(CXX) $(CXXFLAGS) -Wl,--gc-sections main.cpp -o $@
	$(SIZE) $@
build/remote.hex: build/remote.elf
	$(OBJCOPY) -O ihex -R .eeprom $< $@
test:
	g++ -std=c++11 -Wall -Wextra -Werror -pedantic tests/controller_test.cpp -o /tmp/maxx-avr-controller-test
	/tmp/maxx-avr-controller-test
clean:
	rm -rf build
.PHONY: all test clean
