// Game entry, first-game control, shared game state and prompts
// Original CPU range $f8ce-$fa0b.
.assert "60_game_first start", *, $f8ce

// Game-mode entry; homes robot, prompts selection, then dispatches first/second game.
GamesEntry:
    jsr HomeRobot                                          // F8CE
    jsr WaitForTune                                        // F8D1
    ldx #$12                                               // F8D4
    jsr PromptForSmallNumber                               // F8D6
    php                                                    // F8D9

L_F8DA:
    lda #$20                                               // F8DA
    sta ZP_OPERAND                                         // F8DC
    lda #$05                                               // F8DE
    jsr ExecuteMotorCommand                                // F8E0
    plp                                                    // F8E3
    beq L_F8E9                                             // F8E4
    jmp SecondGameEntry                                    // F8E6

L_F8E9:
    jsr ClearGameState                                     // F8E9
    jsr ChooseGameDifficulty                               // F8EC
    stx ZP_GAME_DIFFICULTY                                 // F8EF
    ldx #$14                                               // F8F1
    jsr SpeakPhrase                                        // F8F3
    jsr DisplayGameValue                                   // F8F6
    lda #$02                                               // F8F9
    sta ZP_GAME_TIMER                                      // F8FB
    sta ZP_WHEEL_SPEED                                     // F8FD
    lda #$03                                               // F8FF
    sta ZP_GAME_ROUND                                      // F901
    jsr WaitForRobotActivities                             // F903

L_F906:
    lda #$14                                               // F906
    sta ZP_DELAY_TIMER                                     // F908
    ldx #$20                                               // F90A
    jsr SpeakPhrase                                        // F90C
    jsr WaitForSpeech                                      // F90F
    jsr SetHeadlampOn                                      // F912
    ldx ZP_GAME_DIFFICULTY                                 // F915
    ldy.abs GameEffectIndices, x                           // F917
    jsr ConfigureRandomEffect                              // F91A

L_F91D:
    bit.abs IO_COP_CONTROL_STATUS                          // F91D; V tests game/sensor input bit 6
    bvs L_F92C                                             // F920
    jsr NextRandom                                         // F922
    lda ZP_DELAY_TIMER                                     // F925
    bne L_F91D                                             // F927
    jmp L_F9C6                                             // F929

L_F92C:
    jsr SetHeadlampOff                                     // F92C
    jsr DisableSelectedMusicEffect                         // F92F
    ldx ZP_GAME_DIFFICULTY                                 // F932
    lda.abs GameEffectValues, x                            // F934
    sta ZP_EFFECT0_VALUE                                   // F937
    lda.abs GameDelayTable0, x                             // F939
    sta ZP_DELAY_TIMER                                     // F93C
    jsr ConfigureDecayEffect                               // F93E

L_F941:
    jsr GameWaitForMotion                                  // F941
    lda ZP_DELAY_TIMER                                     // F944
    bne L_F941                                             // F946
    lda #$48                                               // F948
    sta ZP_EFFECT0_VALUE                                   // F94A
    lda #$05                                               // F94C
    sta ZP_EFFECT0_TIMING                                  // F94E
    lda #$ff                                               // F950
    sta ZP_EFFECT0_VALUE_AUX                               // F952
    sta ZP_EFFECT0_REPEAT                                  // F954
    jsr ConfigureSweepEffect                               // F956
    jsr SetHeadlampOn                                      // F959
    ldx ZP_GAME_DIFFICULTY                                 // F95C
    lda.abs GameDelayTable1, x                             // F95E
    sta ZP_SPEED_GAME_TIMER                                // F961

L_F963:
    bit.abs IO_COP_CONTROL_STATUS                          // F963; V tests game/sensor input bit 6
    bvs L_F996                                             // F966
    jsr GameWaitForMotion                                  // F968
    lda ZP_SPEED_GAME_TIMER                                // F96B
    bne L_F963                                             // F96D
    jsr DisableSelectedMusicEffect                         // F96F
    jsr SetHeadlampOff                                     // F972
    ldx #$07                                               // F975
    jsr SelectTune                                         // F977
    jsr WaitForMotorCompletion                             // F97A
    lda ZP_GAME_FLAGS                                      // F97D
    beq L_F984                                             // F97F
    jsr Routine_FA42                                       // F981

L_F984:
    jsr WaitForRobotActivities                             // F984
    inc ZP_GAME_ROUND                                      // F987
    ldx ZP_GAME_DIFFICULTY                                 // F989
    beq L_F98F                                             // F98B
    dec ZP_GAME_DIFFICULTY                                 // F98D

L_F98F:
    dec ZP_GAME_TIMER                                      // F98F
    bmi L_F9C6                                             // F991
    jmp L_F906                                             // F993

L_F996:
    jsr DisableSelectedMusicEffect                         // F996
    jsr SetHeadlampOff                                     // F999
    ldx #$13                                               // F99C
    jsr SpeakPhrase                                        // F99E
    lda ZP_GAME_DIFFICULTY                                 // F9A1
    sed                                                    // F9A3
    sec                                                    // F9A4
    adc ZP_GAME_VALUE_LO                                   // F9A5
    sta ZP_GAME_VALUE_LO                                   // F9A7
    lda ZP_GAME_VALUE_HI                                   // F9A9
    adc #$00                                               // F9AB
    sta ZP_GAME_VALUE_HI                                   // F9AD
    cld                                                    // F9AF
    jsr DisplayGameValue                                   // F9B0
    dec ZP_GAME_ROUND                                      // F9B3
    bpl L_F9C3                                             // F9B5
    ldx ZP_GAME_DIFFICULTY                                 // F9B7
    cpx #$03                                               // F9B9
    bcs L_F9C3                                             // F9BB
    lda #$03                                               // F9BD
    sta ZP_GAME_ROUND                                      // F9BF
    inc ZP_GAME_DIFFICULTY                                 // F9C1

L_F9C3:
    jmp L_F92C                                             // F9C3

L_F9C6:
    jsr DisplayGameValue                                   // F9C6
    jsr DisableSelectedMusicEffect                         // F9C9
    ldx #$1b                                               // F9CC
    jsr SpeakPhrase                                        // F9CE
    jsr WaitForRobotActivities                             // F9D1
    jsr Routine_FA67                                       // F9D4
    php                                                    // F9D7
    jsr HomeRobot                                          // F9D8
    jmp L_F8DA                                             // F9DB

// Clear $A6-$AD with X=7..0. $AD is used despite no direct operand.
ClearGameState:
    ldx #$07                                               // F9DE
    lda #$00                                               // F9E0

L_F9E2:
    sta ZP_GAME_DIFFICULTY, x                              // F9E2
    dex                                                    // F9E4
    bpl L_F9E2                                             // F9E5
    rts                                                    // F9E7

// Prompt for difficulty then use numeric selection helper.
ChooseGameDifficulty:
    ldx #$11                                               // F9E8

// Prompt/operand loop; game/difficulty interpretation depends on caller.
// Shared helper: proximity to game code is not proof of exclusive game ownership.
PromptForSmallNumber:
    jsr SpeakPhrase                                        // F9EA
    lda #$11                                               // F9ED
    sta ZP_OPCODE                                          // F9EF

L_F9F1:
    jsr ReadOperandViaVector                               // F9F1
    bcc L_F9FA                                             // F9F4
    cmp #$04                                               // F9F6
    bcc L_F9FF                                             // F9F8

L_F9FA:
    jsr PlayErrorTone                                      // F9FA
    bmi L_F9F1                                             // F9FD

L_F9FF:
    tax                                                    // F9FF
    rts                                                    // FA00

// Copy game value $A7/$A8 to shared display scratch.
// Shared helper: proximity to game code is not proof of exclusive game ownership.
DisplayGameValue:
    lda ZP_GAME_VALUE_LO                                   // FA01
    sta ZP_DISPLAY_EDIT_LO                                 // FA03
    lda ZP_GAME_VALUE_HI                                   // FA05
    sta ZP_DISPLAY_EDIT_HI                                 // FA07
    jmp DisplayNumberBlanked                               // FA09
.assert "60_game_first end", *, $0fa0c
