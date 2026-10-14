// Second-game control and game arithmetic
// Original CPU range $faa4-$fc6e.
.assert "63_game_second start", *, $faa4

// Second game control; semantic details remain partly unresolved.
SecondGameEntry:
    jsr ClearGameState                                     // FAA4
    sta ZP_DELAY_TIMER                                     // FAA7
    jsr ChooseGameDifficulty                               // FAA9
    txa                                                    // FAAC
    asl                                                    // FAAD
    asl                                                    // FAAE
    sta ZP_GAME_DIFFICULTY                                 // FAAF

L_FAB1:
    jsr NextRandom                                         // FAB1
    lsr                                                    // FAB4
    ora #$08                                               // FAB5
    sta ZP_GAME_ROUND                                      // FAB7
    jsr StopMusicVoice2                                    // FAB9
    jsr SetHeadlampOff                                     // FABC
    lda ZP_DELAY_TIMER                                     // FABF
    bne L_FAE4                                             // FAC1
    jsr Routine_FBCE                                       // FAC3
    inc ZP_GAME_DIFFICULTY                                 // FAC6
    ldy #$18                                               // FAC8
    jsr ConfigureRandomEffect                              // FACA
    lda #$03                                               // FACD
    jsr Routine_FA60                                       // FACF
    jsr StopMusicVoice0                                    // FAD2
    ldx #$68                                               // FAD5
    jsr SpeakDirectSound                                   // FAD7
    jsr Routine_FC34                                       // FADA
    jsr Routine_FA5E                                       // FADD
    lda #$19                                               // FAE0
    sta ZP_DELAY_TIMER                                     // FAE2

L_FAE4:
    lda #$00                                               // FAE4
    sta ZP_GAME_FLAGS                                      // FAE6
    jsr Routine_FBED                                       // FAE8

L_FAEB:
    jsr Routine_FB8C                                       // FAEB
    bcc L_FB00                                             // FAEE
    jsr NextRandom                                         // FAF0
    and #$c0                                               // FAF3
    bne L_FAFD                                             // FAF5
    jsr Routine_FC12                                       // FAF7
    clc                                                    // FAFA
    bcc L_FB00                                             // FAFB

L_FAFD:
    jsr Routine_FBD6                                       // FAFD

L_FB00:
    jsr Routine_FBBF                                       // FB00
    dec ZP_GAME_ROUND                                      // FB03
    bne L_FAEB                                             // FB05
    jsr StopMusicVoice1                                    // FB07
    jsr NextRandom                                         // FB0A
    lsr                                                    // FB0D
    ora #$22                                               // FB0E
    sta ZP_GAME_ROUND                                      // FB10
    and #$0f                                               // FB12
    sta ZP_GAME_PHASE                                      // FB14

L_FB16:
    lda ZP_GAME_FLAGS                                      // FB16
    bne L_FB3D                                             // FB18
    dec ZP_GAME_PHASE                                      // FB1A
    beq L_FB2C                                             // FB1C

L_FB1E:
    jsr Routine_FB8C                                       // FB1E
    bcc L_FB7F                                             // FB21
    jsr Routine_FBD6                                       // FB23
    jsr Routine_FC21                                       // FB26
    jmp L_FB7F                                             // FB29

L_FB2C:
    jsr NextRandom                                         // FB2C
    and #$1f                                               // FB2F
    ora #$04                                               // FB31
    sta ZP_GAME_PHASE                                      // FB33
    jsr Routine_FC00                                       // FB35
    jsr SetHeadlampOn                                      // FB38
    dec ZP_GAME_FLAGS                                      // FB3B

L_FB3D:
    dec ZP_GAME_PHASE                                      // FB3D
    bne L_FB6C                                             // FB3F
    jsr StopMusicVoice2                                    // FB41
    jsr SetHeadlampOff                                     // FB44
    bit ZP_GAME_FLAGS                                      // FB47
    bmi L_FB54                                             // FB49
    lda ZP_GAME_DIFFICULTY                                 // FB4B
    asl                                                    // FB4D
    asl                                                    // FB4E
    asl                                                    // FB4F
    adc #$32                                               // FB50
    sta ZP_SPEED_GAME_TIMER                                // FB52

L_FB54:
    lda #$00                                               // FB54
    sta ZP_GAME_FLAGS                                      // FB56
    jsr NextRandom                                         // FB58
    and #$1f                                               // FB5B
    ora #$0f                                               // FB5D
    sta ZP_GAME_PHASE                                      // FB5F
    jsr Routine_FBB5                                       // FB61
    bne L_FB7F                                             // FB64
    lda #$96                                               // FB66
    sta ZP_MOTOR_DELAY_TIMER                               // FB68
    bne L_FB7F                                             // FB6A

L_FB6C:
    jsr Routine_FBB1                                       // FB6C
    bne L_FB73                                             // FB6F
    beq L_FB1E                                             // FB71

L_FB73:
    jsr NextRandom                                         // FB73
    bit ZP_GAME_FLAGS                                      // FB76
    bpl L_FB7F                                             // FB78
    lsr ZP_GAME_FLAGS                                      // FB7A
    jsr Routine_FC25                                       // FB7C

L_FB7F:
    jsr Routine_FBBF                                       // FB7F
    dec ZP_GAME_ROUND                                      // FB82
    bne L_FB16                                             // FB84
    jsr ServiceViaVector                                   // FB86
    jmp L_FAB1                                             // FB89

Routine_FB8C:
    lda ZP_SPEED_GAME_TIMER                                // FB8C
    bne L_FBA5                                             // FB8E
    jsr Routine_FBB5                                       // FB90
    bne L_FBA7                                             // FB93
    lda ZP_MOTOR_DELAY_TIMER                               // FB95
    bne L_FBA5                                             // FB97
    lda #$96                                               // FB99
    sta ZP_MOTOR_DELAY_TIMER                               // FB9B
    jsr Routine_FBB1                                       // FB9D
    bne L_FBA6                                             // FBA0
    jsr Routine_FC12                                       // FBA2

L_FBA5:
    clc                                                    // FBA5

L_FBA6:
    rts                                                    // FBA6

L_FBA7:
    ldx #$19                                               // FBA7
    cpx ZP_MOTOR_DELAY_TIMER                               // FBA9
    bcs L_FBAF                                             // FBAB
    stx ZP_MOTOR_DELAY_TIMER                               // FBAD

L_FBAF:
    clc                                                    // FBAF
    rts                                                    // FBB0

Routine_FBB1:
    ldx #$01                                               // FBB1
    bne L_FBB7                                             // FBB3

Routine_FBB5:
    ldx #$04                                               // FBB5

L_FBB7:
    cpx ZP_HELD0_ID                                        // FBB7
    beq L_FBBD                                             // FBB9
    cpx ZP_HELD1_ID                                        // FBBB

L_FBBD:
    sec                                                    // FBBD
    rts                                                    // FBBE

Routine_FBBF:
    lda ZP_GAME_DIFFICULTY                                 // FBBF
    asl                                                    // FBC1
    asl                                                    // FBC2
    asl                                                    // FBC3
    tax                                                    // FBC4

L_FBC5:
    ldy #$3c                                               // FBC5

L_FBC7:
    dey                                                    // FBC7
    bne L_FBC7                                             // FBC8
    inx                                                    // FBCA
    bne L_FBC5                                             // FBCB
    rts                                                    // FBCD

Routine_FBCE:
    lda ZP_GAME_DIFFICULTY                                 // FBCE
    jsr ByteToBCD                                          // FBD0
    jmp DisplayNumberBlanked                               // FBD3

Routine_FBD6:
    lda ZP_GAME_DIFFICULTY                                 // FBD6
    lsr                                                    // FBD8
    clc                                                    // FBD9
    adc #$28                                               // FBDA
    sta ZP_EFFECT0_VALUE                                   // FBDC
    lda #$06                                               // FBDE
    sta ZP_EFFECT0_TIMING                                  // FBE0
    lda #$10                                               // FBE2
    sta ZP_EFFECT0_REPEAT                                  // FBE4
    lda #$ff                                               // FBE6
    sta ZP_EFFECT0_VALUE_AUX                               // FBE8
    jmp ConfigureSweepEffect                               // FBEA

Routine_FBED:
    ldy #$01                                               // FBED
    sty ZP_EFFECT1_VALUE                                   // FBEF
    sty ZP_EFFECT1_VALUE_AUX                               // FBF1
    lda #$08                                               // FBF3
    sta ZP_EFFECT1_REPEAT                                  // FBF5
    lda #$20                                               // FBF7
    sec                                                    // FBF9
    sbc ZP_GAME_DIFFICULTY                                 // FBFA
    sta ZP_EFFECT1_TIMING                                  // FBFC
    bne L_FC0F                                             // FBFE

Routine_FC00:
    lda #$20                                               // FC00
    sta ZP_EFFECT2_VALUE                                   // FC02
    lda #$0a                                               // FC04
    sta ZP_EFFECT2_REPEAT                                  // FC06
    ldy #$01                                               // FC08
    sty ZP_EFFECT2_TIMING                                  // FC0A
    iny                                                    // FC0C
    sty ZP_EFFECT2_VALUE_AUX                               // FC0D

L_FC0F:
    jmp L_F2C6                                             // FC0F

Routine_FC12:
    jsr PlayFeedbackTone36                                 // FC12
    sed                                                    // FC15
    sec                                                    // FC16
    ldx #$01                                               // FC17
    lda ZP_GAME_VALUE_LO, x                                // FC19
    sbc #$01                                               // FC1B
    bcc L_FC2F                                             // FC1D
    bcs L_FC2D                                             // FC1F

Routine_FC21:
    ldx #$01                                               // FC21
    bne L_FC27                                             // FC23

Routine_FC25:
    ldx #$00                                               // FC25

L_FC27:
    lda #$01                                               // FC27
    clc                                                    // FC29
    sed                                                    // FC2A
    adc ZP_GAME_VALUE_LO, x                                // FC2B

L_FC2D:
    sta ZP_GAME_VALUE_LO, x                                // FC2D

L_FC2F:
    cld                                                    // FC2F
    cmp #$25                                               // FC30
    beq L_FC3F                                             // FC32

Routine_FC34:
    lda ZP_GAME_VALUE_LO                                   // FC34
    sta ZP_DISPLAY_EDIT_LO                                 // FC36
    lda ZP_GAME_VALUE_HI                                   // FC38
    sta ZP_DISPLAY_EDIT_HI                                 // FC3A
    jmp DisplayNumberZeroFilled                            // FC3C

L_FC3F:
    jsr Routine_FA5E                                       // FC3F
    dex                                                    // FC42
    php                                                    // FC43
    jsr SetHeadlampOff                                     // FC44
    jsr ClearMusicEffectsAndInitialize                     // FC47
    ldx #$18                                               // FC4A
    plp                                                    // FC4C
    bne L_FC50                                             // FC4D
    inx                                                    // FC4F

L_FC50:
    jsr SpeakPhrase                                        // FC50
    dec ZP_GAME_DIFFICULTY                                 // FC53
    lda #$02                                               // FC55
    sta ZP_GAME_ROUND                                      // FC57

L_FC59:
    jsr Routine_FC34                                       // FC59
    jsr Routine_FA5E                                       // FC5C
    jsr Routine_FBCE                                       // FC5F
    jsr Routine_FA5E                                       // FC62
    dec ZP_GAME_ROUND                                      // FC65
    bpl L_FC59                                             // FC67
    jsr Routine_FA67                                       // FC69
    jmp SecondGameEntry                                    // FC6C
.assert "63_game_second end", *, $0fc6f
