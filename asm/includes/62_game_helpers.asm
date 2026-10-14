// Game motion/value helpers and difficulty tables
// Original CPU range $fa1b-$faa3.
.assert "62_game_helpers start", *, $fa1b

// Poll/complete game motion and select subsequent game action.
GameWaitForMotion:
    jsr PollMotorProgressAndService                        // FA1B
    lda #$ff                                               // FA1E
    jsr ExecuteMotorCommand                                // FA20
    lda #$0f                                               // FA23
    bit ZP_MOTOR_STATUS                                    // FA25
    bne L_FA1A                                             // FA27
    lda ZP_GAME_FLAGS                                      // FA29
    bne Routine_FA42                                       // FA2B
    lsr ZP_MOTOR_DIRECTION                                 // FA2D
    asl ZP_MOTOR_DIRECTION                                 // FA2F
    jsr NextRandom                                         // FA31
    ldx ZP_GAME_DIFFICULTY                                 // FA34
    and.abs GameRandomMasks, x                             // FA36
    sta ZP_GAME_FLAGS                                      // FA39
    and #$7f                                               // FA3B
    bit ZP_GAME_FLAGS                                      // FA3D
    jmp L_FA51                                             // FA3F

Routine_FA42:
    lsr ZP_MOTOR_DIRECTION                                 // FA42
    sec                                                    // FA44
    rol ZP_MOTOR_DIRECTION                                 // FA45
    lda ZP_GAME_FLAGS                                      // FA47
    and #$7f                                               // FA49
    ldx #$00                                               // FA4B
    bit ZP_GAME_FLAGS                                      // FA4D
    stx ZP_GAME_FLAGS                                      // FA4F

L_FA51:
    sta ZP_OPERAND                                         // FA51
    bmi L_FA59                                             // FA53
    lda #$03                                               // FA55
    bpl L_FA5B                                             // FA57

L_FA59:
    lda #$00                                               // FA59

L_FA5B:
    jmp ExecuteMotorCommand                                // FA5B

Routine_FA5E:
    lda #$01                                               // FA5E

Routine_FA60:
    sta ZP_DELAY_TIMER                                     // FA60

L_FA62:
    lda ZP_DELAY_TIMER                                     // FA62
    bne L_FA62                                             // FA64
    rts                                                    // FA66

Routine_FA67:
    lda ZP_REMOTE_PRODUCER                                 // FA67
    sta ZP_REMOTE_CONSUMER                                 // FA69
    lda #$80                                               // FA6B
    sta ZP_REMOTE_MAILBOX                                  // FA6D
    ldx #$1c                                               // FA6F
    jsr SpeakPhrase                                        // FA71
    lda #$10                                               // FA74
    sta ZP_DELAY_TIMER                                     // FA76

L_FA78:
    lda ZP_DELAY_TIMER                                     // FA78
    beq L_FA8D                                             // FA7A
    lda ZP_REMOTE_MAILBOX                                  // FA7C
    bmi L_FA78                                             // FA7E
    cmp #$0f                                               // FA80
    bne L_FA8D                                             // FA82
    jsr PlayFeedbackTone3C                                 // FA84
    lda #$80                                               // FA87
    sta ZP_REMOTE_MAILBOX                                  // FA89
    asl                                                    // FA8B
    rts                                                    // FA8C

L_FA8D:
    jmp (ZP_MODE_VECTOR)                                   // FA8D

GameDelayTable0:
    .byte $04, $03, $02, $01 // FA90; Game difficulty-dependent parameters; precise meanings remain partly unresolved.

GameDelayTable1:
    .byte $ff, $c0, $80, $40 // FA94; Game difficulty-dependent parameters; precise meanings remain partly unresolved.

GameRandomMasks:
    .byte $81, $83, $83, $87 // FA98; Game difficulty-dependent parameters; precise meanings remain partly unresolved.

GameEffectIndices:
    .byte $20, $18, $14, $10 // FA9C; Game difficulty-dependent parameters; precise meanings remain partly unresolved.

GameEffectValues:
    .byte $01, $05, $09, $13 // FAA0; Game difficulty-dependent parameters; precise meanings remain partly unresolved.
.assert "62_game_helpers end", *, $0faa4
