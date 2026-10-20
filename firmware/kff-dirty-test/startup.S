.syntax unified
.cpu cortex-m4
.thumb
.section .vectors,"a",%progbits
.word 0x10010000
.word Reset_Handler
.rept 14
.word Fault_Handler
.endr
