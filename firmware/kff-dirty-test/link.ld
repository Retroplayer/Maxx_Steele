ENTRY(Reset_Handler)
MEMORY {
 FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 1024K
 SRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
 CCM (rw) : ORIGIN = 0x10000000, LENGTH = 64K
}
SECTIONS {
 .vectors : { KEEP(*(.vectors)) } > FLASH
 .text : { *(.text*) *(.rodata*) . = ALIGN(4); } > FLASH
 .ramcode : { _sram = .; *(.ramcode*) . = ALIGN(4); _eram = .; } > SRAM AT> FLASH
 _siram = LOADADDR(.ramcode);
 .data : { _sdata = .; *(.data*) . = ALIGN(4); _edata = .; } > SRAM AT> FLASH
 _sidata = LOADADDR(.data);
 .bss (NOLOAD) : { _sbss = .; *(.bss*) *(COMMON) . = ALIGN(4); _ebss = .; } > SRAM
 /DISCARD/ : { *(.comment*) *(.ARM.exidx*) *(.ARM.extab*) }
}
