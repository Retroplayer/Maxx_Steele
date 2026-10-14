// Clock/alarm menu, adjustment commands, and auto-execution toggle
// Original CPU range $f75e-$f7f7.
.assert "51_clock_settings start", *, $f75e

// Sound feedback for invalid clock-menu input then retry.
ClockInvalidKey:
    jsr PlayErrorTone                                      // F75E

// Keys adjust/view time/alarm and toggle auto-execution. Head COP maintains clock state.
ClockMenu:
    jsr WaitForRemoteKey                                   // F761
    cmp #$10                                               // F764
    bmi L_F76B                                             // F766
    jmp L_E17F                                             // F768

L_F76B:
    cmp #$08                                               // F76B
    bpl ClockInvalidKey                                    // F76D
    jsr PlayFeedbackTone3C                                 // F76F
    ldx #$e8                                               // F772
    lda #$e0                                               // F774
    ldy ZP_KEY                                             // F776
    bne L_F77F                                             // F778

L_F77A:
    jsr AdjustClockRepeatedly                              // F77A
    bpl ClockMenu                                          // F77D

L_F77F:
    dex                                                    // F77F
    dey                                                    // F780
    beq L_F77A                                             // F781
    lda #$e1                                               // F783
    ldx #$ea                                               // F785
    dey                                                    // F787
    bne L_F78F                                             // F788

L_F78A:
    jsr AdjustClockRepeatedly                              // F78A
    bpl L_F7B9                                             // F78D

L_F78F:
    dex                                                    // F78F
    dey                                                    // F790
    beq L_F78A                                             // F791
    dey                                                    // F793
    bne L_F79D                                             // F794

L_F796:
    lda #$e0                                               // F796
    jsr SendHeadByte                                       // F798
    beq ClockMenu                                          // F79B

L_F79D:
    lda #$e1                                               // F79D
    dey                                                    // F79F
    beq L_F7B6                                             // F7A0
    dey                                                    // F7A2
    bne L_F7C7                                             // F7A3
    jsr SendHeadByte                                       // F7A5
    lda ZP_ALARM_FLAGS                                     // F7A8
    eor #$80                                               // F7AA
    sta ZP_ALARM_FLAGS                                     // F7AC
    bmi L_F7B4                                             // F7AE
    lda #$ee                                               // F7B0
    bne L_F7B6                                             // F7B2

L_F7B4:
    lda #$eb                                               // F7B4

L_F7B6:
    jsr SendHeadByte                                       // F7B6

L_F7B9:
    lda ZP_REMOTE_MAILBOX                                  // F7B9
    bmi L_F7B9                                             // F7BB

L_F7BD:
    lda #$80                                               // F7BD
    sta ZP_REMOTE_MAILBOX                                  // F7BF
    jsr WaitForKeyOrTimer                                  // F7C1
    jmp L_F796                                             // F7C4

L_F7C7:
    ldx #$11                                               // F7C7
    lda ZP_FEATURE_FLAGS                                   // F7C9
    eor #$10                                               // F7CB; feature bit 4 set enables program execution on alarm
    sta ZP_FEATURE_FLAGS                                   // F7CD
    and #$10                                               // F7CF
    beq L_F7D4                                             // F7D1
    inx                                                    // F7D3

L_F7D4:
    jsr DisplayPreset                                      // F7D4
    beq L_F7BD                                             // F7D7

// A=view select, X=adjust command; $16 controls repeat acceleration, $2A supplies delay.
AdjustClockRepeatedly:
    jsr SendHeadByte                                       // F7D9
    lda #$03                                               // F7DC
    sta ZP_CLOCK_REPEAT                                    // F7DE

L_F7E0:
    txa                                                    // F7E0
    jsr SendHeadByte                                       // F7E1
    lda #$40                                               // F7E4
    ldy ZP_CLOCK_REPEAT                                    // F7E6
    beq L_F7ED                                             // F7E8
    dec ZP_CLOCK_REPEAT                                    // F7EA
    asl                                                    // F7EC

L_F7ED:
    sta ZP_MOTOR_DELAY_TIMER                               // F7ED

L_F7EF:
    lda ZP_MOTOR_DELAY_TIMER                               // F7EF
    beq L_F7E0                                             // F7F1
    bit ZP_REMOTE_MAILBOX                                  // F7F3
    bmi L_F7EF                                             // F7F5
    rts                                                    // F7F7
.assert "51_clock_settings end", *, $0f7f8
