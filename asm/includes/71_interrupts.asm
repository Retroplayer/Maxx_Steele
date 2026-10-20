// IRQ trampoline, register saves, split-table RTS dispatch and restore
// Original CPU range $fdc5-$fde5.
.assert "71_interrupts start", *, $fdc5

// Hardware IRQ trampoline through writable RAM vector $0078/$0079.
IRQEntry:
    jmp (ZP_IRQ_VECTOR)                                    // FDC5

// Save A/X/Y, run receiver, select one of eight tasks, dispatch by pushing target-minus-one and RTS.
IRQDefault:
    pha                                                    // FDC8
    txa                                                    // FDC9
    pha                                                    // FDCA
    tya                                                    // FDCB
    pha                                                    // FDCC
    jsr RemoteService                                      // FDCD
    ldx ZP_IRQ_SLOT                                        // FDD0
    dex                                                    // FDD2
    bpl L_FDD7                                             // FDD3
    ldx #$07                                               // FDD5

L_FDD7:
    stx ZP_IRQ_SLOT                                        // FDD7
    lda ZP_IRQ_TASK0_HI, x                                 // FDD9
    pha                                                    // FDDB
    lda ZP_IRQ_TASK0_LO, x                                 // FDDC
    pha                                                    // FDDE
    rts                                                    // FDDF

// Restore Y/X/A from default IRQ stack frame and RTI.
IRQRestore:
    pla                                                    // FDE0
    tay                                                    // FDE1
    pla                                                    // FDE2
    tax                                                    // FDE3
    pla                                                    // FDE4
    rti                                                    // FDE5
.assert "71_interrupts end", *, $0fde6
