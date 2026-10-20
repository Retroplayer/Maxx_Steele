CROSS ?= arm-none-eabi-
CC = $(CROSS)gcc
CFLAGS = -mcpu=cortex-m4 -mthumb -O3 -g3 -ffreestanding -fno-builtin -fno-common -fno-unwind-tables -fno-asynchronous-unwind-tables -Wall -Wextra -Werror -ffunction-sections -fdata-sections
.PHONY: all clean
all: build/maxx-kff.bin build/maxx-kff.hex build/maxx-kff.lst
image.h: make_image.py
	python3 make_image.py
build:
	mkdir -p build
build/maxx-kff.elf: main.c startup.S link.ld image.h | build
	$(CC) $(CFLAGS) -nostdlib -Wl,-T,link.ld,--gc-sections,-Map,build/maxx-kff.map main.c startup.S -o $@
	$(CROSS)size $@
build/maxx-kff.bin: build/maxx-kff.elf
	$(CROSS)objcopy -O binary $< $@
build/maxx-kff.hex: build/maxx-kff.elf
	$(CROSS)objcopy -O ihex $< $@
build/maxx-kff.lst: build/maxx-kff.elf
	$(CROSS)objdump -d -S $< > $@
clean:
	rm -rf build image.h test-cart.bin
