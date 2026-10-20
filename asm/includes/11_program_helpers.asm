// Command reversal, cursor helpers, operand entry, and limits
// Original CPU range $e54d-$e616.
.assert "11_program_helpers start", *, $e54d

ReverseMotionMap:
    .byte $00, $02, $01, $03, $05, $04, $07, $06 // E54D; Reverse-execution operation remap: left/reverse/forward/right/wrist/arm pairs.

// Carry clear at beginning ($0180); otherwise subtract two and return carry set. Listing labels repaired from binary.
RetreatProgramCursor:
    lda #>(USER_PROGRAM-$80)                               // E555
    cmp ZP_PROGRAM_CURSOR_HI                               // E557
    bne L_E568                                             // E559
    lda ZP_PROGRAM_CURSOR_LO                               // E55B
    cmp #<(USER_PROGRAM-$80)                               // E55D
    bne L_E568                                             // E55F
    ldx #$0f                                               // E561
    jsr DisplayPreset                                      // E563
    clc                                                    // E566
    rts                                                    // E567

L_E568:
    lda ZP_PROGRAM_CURSOR_LO                               // E568
    bne L_E56E                                             // E56A
    dec ZP_PROGRAM_CURSOR_HI                               // E56C

L_E56E:
    dec ZP_PROGRAM_CURSOR_LO                               // E56E
    dec ZP_PROGRAM_CURSOR_LO                               // E570
    sec                                                    // E572
    rts                                                    // E573

// Feature bit 6 controls whether the existing cursor/program is retained.
ResetCursorUnlessEditing:
    bit ZP_FEATURE_FLAGS                                   // E574
    bvs L_E581                                             // E576
    jsr ResetProgramCursor                                 // E578

// Write $FF at biased cursor+$80.
MarkProgramEnd:
    lda #$ff                                               // E57B
    ldy #$80                                               // E57D
    sta (ZP_PROGRAM_CURSOR_LO), y                          // E57F

L_E581:
    rts                                                    // E581

// Initialize biased cursor to USER_PROGRAM-$80; reset execution direction state.
ResetProgramCursor:
    lda #<(USER_PROGRAM-$80)                               // E582
    sta ZP_PROGRAM_CURSOR_LO                               // E584
    lda #>(USER_PROGRAM-$80)                               // E586
    sta ZP_PROGRAM_CURSOR_HI                               // E588
    lda ZP_PROGRAM_FLAGS                                   // E58A
    and #$bf                                               // E58C
    sta ZP_PROGRAM_FLAGS                                   // E58E
    lda #$00                                               // E590
    sta ZP_MOTOR_DIRECTION                                 // E592
    rts                                                    // E594

// Indirect command-input hook, initially ReadOperandDefault.
ReadOperandViaVector:
    jmp (ZP_OPERAND_VECTOR)                                // E595

// Numeric operand entry and per-command bounds; carry indicates acceptance.
ReadOperandDefault:
    jsr DisplayOperandPrompt                               // E598
    asl ZP_UI_FLAGS                                        // E59B
    sec                                                    // E59D
    ror ZP_UI_FLAGS                                        // E59E
    lda #$00                                               // E5A0
    sta ZP_OPERAND                                         // E5A2

L_E5A4:
    jsr WaitForRemoteKey                                   // E5A4
    cmp #$0f                                               // E5A7
    beq L_E5E0                                             // E5A9
    cmp #$0a                                               // E5AB
    bpl L_E5DA                                             // E5AD
    asl ZP_OPERAND                                         // E5AF
    bcs L_E5DA                                             // E5B1
    adc ZP_OPERAND                                         // E5B3
    bcs L_E5DA                                             // E5B5
    asl ZP_OPERAND                                         // E5B7
    bcs L_E5DA                                             // E5B9
    asl ZP_OPERAND                                         // E5BB
    bcs L_E5DA                                             // E5BD
    adc ZP_OPERAND                                         // E5BF
    bcs L_E5DA                                             // E5C1
    ldx ZP_OPERATION_INDEX                                 // E5C3
    cmp.abs OperandLimits, x                               // E5C5
    beq L_E5CC                                             // E5C8
    bcs L_E5DA                                             // E5CA

L_E5CC:
    sta ZP_OPERAND                                         // E5CC
    asl ZP_UI_FLAGS                                        // E5CE
    lsr ZP_UI_FLAGS                                        // E5D0
    jsr DisplayCommandOperand                              // E5D2
    jsr PlayFeedbackTone3C                                 // E5D5
    bmi L_E5A4                                             // E5D8

L_E5DA:
    lda #$00                                               // E5DA
    sta ZP_OPERAND                                         // E5DC
    clc                                                    // E5DE
    rts                                                    // E5DF

L_E5E0:
    jsr PlayFeedbackTone3C                                 // E5E0
    lda #$2f                                               // E5E3
    jsr WaitForSpecificRemoteEvent                         // E5E5
    lda ZP_OPERAND                                         // E5E8
    sec                                                    // E5EA
    rts                                                    // E5EB

OperandLimits:
    .byte $63 // E5EC; Operand upper bound, operation/table index $00.
    .byte $ff // E5ED; Operand upper bound, operation/table index $01.
    .byte $ff // E5EE; Operand upper bound, operation/table index $02.
    .byte $63 // E5EF; Operand upper bound, operation/table index $03.
    .byte $63 // E5F0; Operand upper bound, operation/table index $04.
    .byte $63 // E5F1; Operand upper bound, operation/table index $05.
    .byte $63 // E5F2; Operand upper bound, operation/table index $06.
    .byte $63 // E5F3; Operand upper bound, operation/table index $07.
    .byte $54 // E5F4; Operand upper bound, operation/table index $08.
    .byte $01 // E5F5; Operand upper bound, operation/table index $09.
    .byte $01 // E5F6; Operand upper bound, operation/table index $0a.
    .byte $ff // E5F7; Operand upper bound, operation/table index $0b.
    .byte $ff // E5F8; Operand upper bound, operation/table index $0c.
    .byte $08 // E5F9; Operand upper bound, operation/table index $0d.
    .byte $8c // E5FA; Operand upper bound, operation/table index $0e.
    .byte $20 // E5FB; Operand upper bound, operation/table index $0f.
    .byte $0f // E5FC; Operand upper bound, operation/table index $10.
    .byte $09 // E5FD; Operand upper bound, operation/table index $11.
    .byte $63 // E5FE; Operand upper bound, operation/table index $12.
    .byte $ff // E5FF; Operand upper bound, operation/table index $13.

// A selects event to wait for; consumes mailbox events and waits again on mismatch.
WaitForSpecificRemoteEvent:
    ldy #$80                                               // E600

L_E602:
    bit ZP_REMOTE_MAILBOX                                  // E602
    bmi L_E602                                             // E604
    cmp ZP_REMOTE_MAILBOX                                  // E606
    sty ZP_REMOTE_MAILBOX                                  // E608
    bne L_E602                                             // E60A
    rts                                                    // E60C

// Wait for a foreground key below $20, servicing robot and mode handling.
WaitForRemoteKey:
    jsr ReadRemoteAndHandleModes                           // E60D
    lda ZP_KEY                                             // E610
    cmp #$20                                               // E612
    bpl WaitForRemoteKey                                   // E614
    rts                                                    // E616
.assert "11_program_helpers end", *, $0e617
