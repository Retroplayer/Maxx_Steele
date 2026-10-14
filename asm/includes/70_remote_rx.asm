// IRQ receiver state machine, checksum, held keys, and event queue
// Original CPU range $fc6f-$fdc4.
.assert "70_remote_rx start", *, $fc6f

// Runs every IRQ. Software serial decoder on $1400 bit 7, held-key aging and event delivery.
RemoteService:
    ldy #$00                                               // FC6F

L_FC71:
    ldx ZP_HELD0_AGE, y                                    // FC71
    cpx #$ff                                               // FC73
    beq L_FC8B                                             // FC75
    inx                                                    // FC77
    cpx #$c8                                               // FC78
    bne L_FC89                                             // FC7A
    lda #$20                                               // FC7C
    ora.abs ZP_HELD0_ID, y                                 // FC7E
    jsr EnqueueRemoteEvent                                 // FC81
    stx ZP_HELD0_ID, y                                     // FC84
    stx ZP_HELD0_CODE, y                                   // FC86
    dex                                                    // FC88

L_FC89:
    stx ZP_HELD0_AGE, y                                    // FC89

L_FC8B:
    dey                                                    // FC8B
    bpl L_FC92                                             // FC8C
    ldy #$03                                               // FC8E
    bne L_FC71                                             // FC90

L_FC92:
    ldy ZP_REMOTE_STATE                                    // FC92
    bne L_FCAD                                             // FC94
    bit.abs IO_SPEECH_REMOTE                               // FC96; N tests radio input bit 7
    bpl L_FCA8                                             // FC99
    ldx ZP_REMOTE_SAMPLE                                   // FC9B
    inx                                                    // FC9D
    cpx #$02                                               // FC9E
    bne L_FCAA                                             // FCA0
    inc ZP_REMOTE_STATE                                    // FCA2
    ldx #$01                                               // FCA4
    bne L_FCAA                                             // FCA6

L_FCA8:
    ldx #$00                                               // FCA8

L_FCAA:
    jmp PublishRemoteEvent                                 // FCAA

L_FCAD:
    cpy #$04                                               // FCAD
    beq L_FCB5                                             // FCAF
    cpy #$08                                               // FCB1
    bne L_FCF4                                             // FCB3

L_FCB5:
    lda.abs IO_SPEECH_REMOTE                               // FCB5; subsequent two ROLs move original input bit 7 to bit 0
    rol                                                    // FCB8
    rol                                                    // FCB9
    eor ZP_REMOTE_SHIFT                                    // FCBA
    and #$01                                               // FCBC
    clv                                                    // FCBE
    clc                                                    // FCBF
    adc #$7f                                               // FCC0
    ldx ZP_REMOTE_SAMPLE                                   // FCC2
    bne L_FCD5                                             // FCC4
    lda #$7f                                               // FCC6
    and ZP_REMOTE_SHIFT                                    // FCC8
    sta ZP_REMOTE_SHIFT                                    // FCCA
    bvc L_FCD0                                             // FCCC
    inc ZP_REMOTE_SAMPLE                                   // FCCE

L_FCD0:
    inc ZP_REMOTE_SAMPLE                                   // FCD0

L_FCD2:
    jmp L_FDAF                                             // FCD2

L_FCD5:
    dex                                                    // FCD5
    bne L_FCE4                                             // FCD6
    bvs L_FCD0                                             // FCD8
    lda ZP_REMOTE_SHIFT                                    // FCDA
    bmi L_FCEC                                             // FCDC
    ora #$80                                               // FCDE
    sta ZP_REMOTE_SHIFT                                    // FCE0
    bmi L_FCD2                                             // FCE2

L_FCE4:
    bvc L_FCEC                                             // FCE4
    inc ZP_REMOTE_STATE                                    // FCE6
    ldx #$00                                               // FCE8
    beq L_FD25                                             // FCEA

L_FCEC:
    inc ZP_REMOTE_ERRORS                                   // FCEC
    ldx #$00                                               // FCEE
    stx ZP_REMOTE_STATE                                    // FCF0
    beq L_FD25                                             // FCF2

L_FCF4:
    ldx ZP_REMOTE_SAMPLE                                   // FCF4
    cpx #$02                                               // FCF6
    bne L_FCD0                                             // FCF8
    ldx #$00                                               // FCFA
    clc                                                    // FCFC
    bit.abs IO_SPEECH_REMOTE                               // FCFD; N tests radio input bit 7
    bpl L_FD03                                             // FD00
    sec                                                    // FD02

L_FD03:
    rol ZP_REMOTE_SHIFT                                    // FD03
    ldy ZP_REMOTE_STATE                                    // FD05
    cpy #$0a                                               // FD07
    beq L_FD0F                                             // FD09
    inc ZP_REMOTE_STATE                                    // FD0B
    bne L_FD25                                             // FD0D

L_FD0F:
    stx ZP_REMOTE_STATE                                    // FD0F
    ldy ZP_REMOTE_SHIFT                                    // FD11
    cpy ZP_HELD0_CODE                                      // FD13
    bne L_FD1B                                             // FD15
    stx ZP_HELD0_AGE                                       // FD17
    beq L_FD21                                             // FD19

L_FD1B:
    cpy ZP_HELD1_CODE                                      // FD1B
    bne L_FD28                                             // FD1D
    stx ZP_HELD1_AGE                                       // FD1F

L_FD21:
    stx ZP_INACTIVITY_HI                                   // FD21
    stx ZP_INACTIVITY_LO                                   // FD23

L_FD25:
    jmp PublishRemoteEvent                                 // FD25

L_FD28:
    tya                                                    // FD28
    and #$c0                                               // FD29
    clc                                                    // FD2B
    rol                                                    // FD2C
    rol                                                    // FD2D
    rol                                                    // FD2E
    sta ZP_REMOTE_SAMPLE                                   // FD2F
    tya                                                    // FD31
    ldy #$06                                               // FD32

L_FD34:
    lsr                                                    // FD34
    bcc L_FD38                                             // FD35
    inx                                                    // FD37

L_FD38:
    dey                                                    // FD38
    bne L_FD34                                             // FD39
    txa                                                    // FD3B
    ldx #$00                                               // FD3C
    and #$03                                               // FD3E
    cmp ZP_REMOTE_SAMPLE                                   // FD40
    beq L_FD49                                             // FD42
    inc ZP_REMOTE_ERRORS                                   // FD44
    jmp PublishRemoteEvent                                 // FD46

L_FD49:
    lda #$20                                               // FD49
    bit ZP_REMOTE_SHIFT                                    // FD4B
    beq L_FD73                                             // FD4D
    lda ZP_REMOTE_SHIFT                                    // FD4F
    and #$1f                                               // FD51
    cmp ZP_HELD0_ID                                        // FD53
    bne L_FD60                                             // FD55
    stx ZP_HELD0_CODE                                      // FD57
    stx ZP_HELD0_ID                                        // FD59
    dex                                                    // FD5B
    stx ZP_HELD0_AGE                                       // FD5C
    bne L_FD6B                                             // FD5E

L_FD60:
    cmp ZP_HELD1_ID                                        // FD60
    bne L_FD70                                             // FD62
    stx ZP_HELD1_CODE                                      // FD64
    stx ZP_HELD1_ID                                        // FD66
    dex                                                    // FD68
    stx ZP_HELD1_AGE                                       // FD69

L_FD6B:
    ora #$20                                               // FD6B
    jsr EnqueueRemoteEvent                                 // FD6D

L_FD70:
    jmp PublishRemoteEvent                                 // FD70

L_FD73:
    ldy ZP_REMOTE_SHIFT                                    // FD73
    cpy #$d9                                               // FD75
    beq L_FD8E                                             // FD77
    tya                                                    // FD79
    and #$3f                                               // FD7A
    cpx ZP_HELD0_ID                                        // FD7C
    bne L_FD88                                             // FD7E
    stx ZP_HELD0_AGE                                       // FD80
    sty ZP_HELD0_CODE                                      // FD82
    sta ZP_HELD0_ID                                        // FD84
    beq L_FDAA                                             // FD86

L_FD88:
    cpx ZP_HELD1_ID                                        // FD88
    beq L_FDA4                                             // FD8A
    inc ZP_REMOTE_SLOT_ERRORS                              // FD8C

L_FD8E:
    stx ZP_REMOTE_SAMPLE                                   // FD8E
    jmp (ZP_MODE_VECTOR)                                   // FD90

// Convert one-based event to queue code, store ring entry, decrement/wrap producer.
EnqueueRemoteEvent:
    ldx ZP_REMOTE_PRODUCER                                 // FD93
    clc                                                    // FD95
    adc #$ff                                               // FD96
    sta ZP_REMOTE_RING_0, x                                // FD98
    dex                                                    // FD9A
    bpl L_FD9F                                             // FD9B
    ldx #$03                                               // FD9D

L_FD9F:
    stx ZP_REMOTE_PRODUCER                                 // FD9F
    ldx #$00                                               // FDA1
    rts                                                    // FDA3

L_FDA4:
    stx ZP_HELD1_AGE                                       // FDA4
    sty ZP_HELD1_CODE                                      // FDA6
    sta ZP_HELD1_ID                                        // FDA8

L_FDAA:
    jsr EnqueueRemoteEvent                                 // FDAA

// Publish queued event if foreground mailbox is empty.
PublishRemoteEvent:
    stx ZP_REMOTE_SAMPLE                                   // FDAD

L_FDAF:
    bit ZP_REMOTE_MAILBOX                                  // FDAF
    bpl L_FDC4                                             // FDB1
    ldx ZP_REMOTE_CONSUMER                                 // FDB3
    cpx ZP_REMOTE_PRODUCER                                 // FDB5
    beq L_FDC4                                             // FDB7
    ldy ZP_REMOTE_RING_0, x                                // FDB9
    sty ZP_REMOTE_MAILBOX                                  // FDBB
    dex                                                    // FDBD
    bpl L_FDC2                                             // FDBE
    ldx #$03                                               // FDC0

L_FDC2:
    stx ZP_REMOTE_CONSUMER                                 // FDC2

L_FDC4:
    rts                                                    // FDC4
.assert "70_remote_rx end", *, $0fdc5
