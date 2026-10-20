// Foreground modes, settings, LEARN storage, editing, and execution
// Original CPU range $e0cb-$e54c.
.assert "10_modes_program start", *, $e0cb

// Normal foreground entry. Initializes immediate-mode state and resets the stack later.
MainModeEntry:
    cli                                                    // E0CB
    lda #$80                                               // E0CC
    sta ZP_REMOTE_MAILBOX                                  // E0CE
    asl                                                    // E0D0

// Store mode and dispatch to its user interface; this path is not a callable API.
EnterForegroundMode:
    sta ZP_MODE                                            // E0D1
    tax                                                    // E0D3
    inx                                                    // E0D4
    jsr SelectTune                                         // E0D5
    ldx #$00                                               // E0D8
    stx ZP_UI_FLAGS                                        // E0DA
    stx ZP_SPEECH_STATE                                    // E0DC
    stx ZP_SUBMENU                                         // E0DE
    stx ZP_MOTION_RESULT                                   // E0E0
    stx ZP_INACTIVITY_LO                                   // E0E2
    stx ZP_INACTIVITY_HI                                   // E0E4
    stx ZP_MUSIC_EDIT_FLAGS                                // E0E6
    dex                                                    // E0E8
    txs                                                    // E0E9
    jsr StopAllMotors                                      // E0EA
    lda ZP_MODE                                            // E0ED
    beq L_E154                                             // E0EF
    clc                                                    // E0F1
    adc #$05                                               // E0F2
    tax                                                    // E0F4
    jsr DisplayPreset                                      // E0F5
    ldx ZP_MODE                                            // E0F8
    dex                                                    // E0FA
    bne L_E122                                             // E0FB
    jsr WaitForKeyOrTimer                                  // E0FD

L_E100:
    jsr PollRobotAndRemote                                 // E100
    cpx #$10                                               // E103
    bne L_E10A                                             // E105
    jmp LearnUserTune                                      // E107

L_E10A:
    lda ZP_MUSIC0_STATE                                    // E10A
    bne L_E100                                             // E10C
    lda ZP_SAVED_DIRECTION                                 // E10E
    and #$01                                               // E110
    sta ZP_MOTOR_DIRECTION                                 // E112
    jsr ResetCursorUnlessEditing                           // E114
    jsr DisplayProgramPosition                             // E117
    ldx #$1e                                               // E11A
    jsr SpeakPromptUnlessDisabled                          // E11C
    jmp ImmediateLearnCommandLoop                          // E11F

L_E122:
    dex                                                    // E122
    bne L_E148                                             // E123
    jsr WaitForKeyOrTimer                                  // E125

L_E128:
    jsr PollRobotAndRemote                                 // E128
    cpx #$10                                               // E12B
    bne L_E132                                             // E12D
    jmp ProgramUserTune                                    // E12F

L_E132:
    cpx #$12                                               // E132
    bne L_E139                                             // E134
    jmp EditSpeechPhrase                                   // E136

L_E139:
    lda ZP_MUSIC0_STATE                                    // E139
    bne L_E128                                             // E13B
    jsr ResetCursorUnlessEditing                           // E13D
    ldx #$1f                                               // E140
    jsr SpeakPromptUnlessDisabled                          // E142
    jmp EditProgramLoop                                    // E145

L_E148:
    dex                                                    // E148
    bne L_E151                                             // E149
    jsr WaitForTune                                        // E14B
    jmp ExecuteProgram                                     // E14E

L_E151:
    jmp (ZP_GAME_VECTOR)                                   // E151

L_E154:
    jsr WaitForTune                                        // E154
    ldx #$20                                               // E157
    jsr SpeakPromptUnlessDisabled                          // E159

L_E15C:
    lda #$e0                                               // E15C
    jsr SendHeadByte                                       // E15E

// Read and classify keys in immediate/LEARN operation.
ImmediateLearnCommandLoop:
    lda #$00                                               // E161
    sta ZP_SUBMENU                                         // E163
    jsr ReadRemoteAndHandleModes                           // E165
    lda ZP_KEY                                             // E168
    ldx ZP_MODE                                            // E16A
    beq L_E17B                                             // E16C
    cmp #$0e                                               // E16E
    bne L_E17F                                             // E170
    jsr ClearProgramStep                                   // E172
    jsr DisplayProgramPosition                             // E175
    jmp ImmediateLearnCommandLoop                          // E178

L_E17B:
    cmp #$0c                                               // E17B
    beq L_E1AA                                             // E17D

L_E17F:
    ldx ZP_SUBMENU                                         // E17F
    bne L_E1BC                                             // E181
    cmp #$2c                                               // E183
    bne L_E18B                                             // E185
    lda #$1c                                               // E187
    bne L_E1B4                                             // E189

L_E18B:
    cmp #$29                                               // E18B
    bpl ImmediateLearnCommandLoop                          // E18D
    cmp #$20                                               // E18F
    bmi L_E199                                             // E191
    and #$0f                                               // E193
    ora #$10                                               // E195
    bne L_E1B4                                             // E197

L_E199:
    cmp #$10                                               // E199
    bpl L_E1BC                                             // E19B
    cmp #$0f                                               // E19D
    bne L_E1A6                                             // E19F
    jsr PlayFeedbackTone3C                                 // E1A1
    bmi ImmediateLearnCommandLoop                          // E1A4

L_E1A6:
    cmp #$0d                                               // E1A6
    bmi L_E1AF                                             // E1A8

L_E1AA:
    jsr PlayErrorTone                                      // E1AA
    bmi ImmediateLearnCommandLoop                          // E1AD

L_E1AF:
    jsr PlayFeedbackTone3C                                 // E1AF
    lda ZP_KEY                                             // E1B2

L_E1B4:
    sta ZP_OPCODE                                          // E1B4
    jsr HandleImmediateMotion                              // E1B6

L_E1B9:
    jmp ImmediateLearnCommandLoop                          // E1B9

L_E1BC:
    lda ZP_SUBMENU                                         // E1BC
    ora #$80                                               // E1BE
    sta ZP_OPCODE                                          // E1C0
    jsr PlayFeedbackTone3C                                 // E1C2
    jsr WaitForKeyOrTimer                                  // E1C5
    ldx ZP_SUBMENU                                         // E1C8
    dex                                                    // E1CA
    bne L_E1EB                                             // E1CB

L_E1CD:
    jsr ReadOperandViaVector                               // E1CD
    bcs L_E1DD                                             // E1D0
    lda ZP_KEY                                             // E1D2
    cmp #$0a                                               // E1D4

L_E1D6:
    bpl L_E17F                                             // E1D6
    jsr PlayErrorTone                                      // E1D8
    bmi L_E1CD                                             // E1DB

L_E1DD:
    ldx ZP_OPERAND                                         // E1DD
    jsr SelectTune                                         // E1DF

L_E1E2:
    jsr InsertCurrentCommandIfLearning                     // E1E2
    lda ZP_MODE                                            // E1E5
    beq L_E23D                                             // E1E7
    bne L_E1B9                                             // E1E9

L_E1EB:
    dex                                                    // E1EB
    beq L_E1F1                                             // E1EC
    dex                                                    // E1EE
    bne L_E207                                             // E1EF

L_E1F1:
    jsr ReadOperandViaVector                               // E1F1
    bcs L_E201                                             // E1F4
    lda ZP_KEY                                             // E1F6
    cmp #$0a                                               // E1F8
    bpl L_E1D6                                             // E1FA
    jsr PlayErrorTone                                      // E1FC
    bmi L_E1F1                                             // E1FF

L_E201:
    jsr ExecuteSpeechCommand                               // E201
    jmp L_E1E2                                             // E204

L_E207:
    lda ZP_MODE                                            // E207
    bne L_E23D                                             // E209
    dex                                                    // E20B
    bne L_E289                                             // E20C

// Settings keys 0..6; index=19+2*key selects paired display presets.
ReadStatusOption:
    jsr WaitForRemoteKey                                   // E20E
    cmp #$10                                               // E211
    bpl L_E1D6                                             // E213
    cmp #$07                                               // E215
    bmi L_E21E                                             // E217
    jsr PlayErrorTone                                      // E219
    bmi ReadStatusOption                                   // E21C

L_E21E:
    jsr PlayFeedbackTone3C                                 // E21E
    lda ZP_KEY                                             // E221
    asl                                                    // E223
    clc                                                    // E224
    adc #$13                                               // E225
    tax                                                    // E227
    ldy ZP_KEY                                             // E228
    bne L_E240                                             // E22A
    lda ZP_PROGRAM_FLAGS                                   // E22C
    eor #$80                                               // E22E; bit 7 set selects parallel program execution
    sta ZP_PROGRAM_FLAGS                                   // E230

L_E232:
    and #$80                                               // E232

L_E234:
    beq L_E237                                             // E234
    inx                                                    // E236

L_E237:
    jsr DisplayPreset                                      // E237

L_E23A:
    jsr WaitForKeyOrTimer                                  // E23A

L_E23D:
    jmp L_E15C                                             // E23D

L_E240:
    dey                                                    // E240
    bne L_E24C                                             // E241
    lda ZP_FEATURE_FLAGS                                   // E243
    eor #$80                                               // E245; feature bit 7 set disables automatic power-down
    sta ZP_FEATURE_FLAGS                                   // E247
    jmp L_E232                                             // E249

L_E24C:
    dey                                                    // E24C
    bne L_E259                                             // E24D
    lda ZP_FEATURE_FLAGS                                   // E24F
    eor #$40                                               // E251; feature bit 6 set enables editing/preserves existing program
    sta ZP_FEATURE_FLAGS                                   // E253
    asl                                                    // E255
    jmp L_E232                                             // E256

L_E259:
    dey                                                    // E259
    bne L_E26F                                             // E25A
    lda ZP_FEATURE_FLAGS                                   // E25C
    eor #$01                                               // E25E; feature bit 0 set disables wrist/arm coupling
    sta ZP_FEATURE_FLAGS                                   // E260
    lsr                                                    // E262
    bcc L_E266                                             // E263
    inx                                                    // E265

L_E266:
    jsr DisplayPreset                                      // E266
    jsr StopAllMotors                                      // E269
    jmp L_E23A                                             // E26C

L_E26F:
    dey                                                    // E26F
    bne L_E27D                                             // E270
    lda ZP_PROGRAM_FLAGS                                   // E272
    eor #$02                                               // E274; program bit 1 set disables alternate backwards execution
    sta ZP_PROGRAM_FLAGS                                   // E276

L_E278:
    and #$02                                               // E278
    jmp L_E234                                             // E27A

L_E27D:
    dey                                                    // E27D
    bne L_E294                                             // E27E
    lda ZP_FEATURE_FLAGS                                   // E280
    eor #$02                                               // E282; feature bit 1 set suppresses verbal prompts
    sta ZP_FEATURE_FLAGS                                   // E284
    jmp L_E278                                             // E286

L_E289:
    dex                                                    // E289
    bne L_E29F                                             // E28A
    ldx #$04                                               // E28C
    jsr DisplayPreset                                      // E28E
    jmp EditUserTune                                       // E291

L_E294:
    ldx #$07                                               // E294
    jsr SelectTune                                         // E296
    jsr WaitForTune                                        // E299
    jmp EnterSleep                                         // E29C

L_E29F:
    jmp ClockMenu                                          // E29F

// LEARN-mode motion bookkeeping before storing a command.
RecordLearnMotion:
    ldy ZP_MODE                                            // E2A2
    dey                                                    // E2A4
    bne L_E2C4                                             // E2A5
    lda ZP_MOTOR_DIRECTION                                 // E2A7
    sta ZP_SAVED_DIRECTION                                 // E2A9
    lda #$00                                               // E2AB
    sta ZP_OPERAND                                         // E2AD
    beq InsertProgramCommand                               // E2AF

// Search earlier learned operation and replace its operand when appropriate.
UpdateLearnOperand:
    ldy ZP_MODE                                            // E2B1
    dey                                                    // E2B3
    bne L_E2C4                                             // E2B4
    ldy #$7e                                               // E2B6
    lda ZP_OPCODE                                          // E2B8
    and #$0f                                               // E2BA

L_E2BC:
    cmp (ZP_PROGRAM_CURSOR_LO), y                          // E2BC
    beq L_E2C5                                             // E2BE
    dey                                                    // E2C0
    dey                                                    // E2C1
    bne L_E2BC                                             // E2C2

L_E2C4:
    rts                                                    // E2C4

L_E2C5:
    iny                                                    // E2C5
    lda ZP_TEMP_VALUE                                      // E2C6
    sta (ZP_PROGRAM_CURSOR_LO), y                          // E2C8
    rts                                                    // E2CA

// Guarded insertion entry: mode must be LEARN before falling into insertion.
InsertCurrentCommandIfLearning:
    ldy ZP_MODE                                            // E2CB
    dey                                                    // E2CD
    bne L_E2C4                                             // E2CE

// Find the end marker, enforce biased cursor $037E boundary, shift pairs, and insert.
InsertProgramCommand:
    lda ZP_PROGRAM_FLAGS                                   // E2D0
    ora #$40                                               // E2D2
    sta ZP_PROGRAM_FLAGS                                   // E2D4

// Copy biased cursor to temporary pointer and scan/shift command pairs.
PrepareProgramInsertion:
    lda ZP_PROGRAM_CURSOR_LO                               // E2D6
    sta ZP_DISPLAY_EDIT_LO                                 // E2D8
    lda ZP_PROGRAM_CURSOR_HI                               // E2DA
    sta ZP_DISPLAY_EDIT_HI                                 // E2DC
    ldy #$7e                                               // E2DE

L_E2E0:
    lda #>(USER_PROGRAM_END-2-$80)                         // E2E0
    cmp ZP_DISPLAY_EDIT_HI                                 // E2E2
    bne L_E2FF                                             // E2E4
    lda #<(USER_PROGRAM_END-2-$80)                         // E2E6
    cmp ZP_DISPLAY_EDIT_LO                                 // E2E8
    bne L_E2FF                                             // E2EA

L_E2EC:
    ldx #$1d                                               // E2EC
    jsr SpeakPhrase                                        // E2EE
    ldx #$0c                                               // E2F1
    jsr DisplayPreset                                      // E2F3
    jsr WaitForSpeech                                      // E2F6
    jsr WaitForKeyOrTimer                                  // E2F9
    jmp (ZP_MODE_VECTOR)                                   // E2FC

L_E2FF:
    inc ZP_DISPLAY_EDIT_LO                                 // E2FF
    inc ZP_DISPLAY_EDIT_LO                                 // E301
    bne L_E307                                             // E303
    inc ZP_DISPLAY_EDIT_HI                                 // E305

L_E307:
    lda (ZP_DISPLAY_EDIT_LO), y                            // E307
    cmp #$ff                                               // E309
    bne L_E2E0                                             // E30B

L_E30D:
    ldy #$7e                                               // E30D
    lda (ZP_DISPLAY_EDIT_LO), y                            // E30F
    ldy #$80                                               // E311
    sta (ZP_DISPLAY_EDIT_LO), y                            // E313
    dey                                                    // E315
    lda (ZP_DISPLAY_EDIT_LO), y                            // E316
    ldy #$81                                               // E318
    sta (ZP_DISPLAY_EDIT_LO), y                            // E31A
    lda ZP_DISPLAY_EDIT_LO                                 // E31C
    bne L_E322                                             // E31E
    dec ZP_DISPLAY_EDIT_HI                                 // E320

L_E322:
    dec ZP_DISPLAY_EDIT_LO                                 // E322
    dec ZP_DISPLAY_EDIT_LO                                 // E324
    lda ZP_PROGRAM_CURSOR_LO                               // E326
    cmp ZP_DISPLAY_EDIT_LO                                 // E328
    bne L_E30D                                             // E32A
    lda ZP_PROGRAM_CURSOR_HI                               // E32C
    cmp ZP_DISPLAY_EDIT_HI                                 // E32E
    bne L_E30D                                             // E330
    lda ZP_OPCODE                                          // E332
    dey                                                    // E334
    sta (ZP_PROGRAM_CURSOR_LO), y                          // E335
    iny                                                    // E337
    lda ZP_OPERAND                                         // E338
    sta (ZP_PROGRAM_CURSOR_LO), y                          // E33A
    lda #$00                                               // E33C
    sta ZP_SUBMENU                                         // E33E
    jsr AdvanceProgramCursor                               // E340
    jmp DisplayProgramPosition                             // E343

// Program-mode editing loop; reads keys and supports clear/backstep/execute.
EditProgramLoop:
    jsr DisplayProgramPosition                             // E346

L_E349:
    lda #$00                                               // E349
    sta ZP_SUBMENU                                         // E34B
    jsr WaitForRemoteKey                                   // E34D
    ldx ZP_KEY                                             // E350
    cpx #$0e                                               // E352
    bne L_E35B                                             // E354
    jsr ClearProgramStep                                   // E356
    bpl EditProgramLoop                                    // E359

L_E35B:
    jsr PlayFeedbackTone3C                                 // E35B
    ldx ZP_KEY                                             // E35E
    cpx #$0f                                               // E360
    bne L_E36A                                             // E362
    jsr ExecuteSelectedStep                                // E364
    jmp EditProgramLoop                                    // E367

L_E36A:
    cpx #$13                                               // E36A
    bne L_E374                                             // E36C
    jsr ProgramBackstep                                    // E36E
    jmp EditProgramLoop                                    // E371

L_E374:
    lda.abs RemoteActionMap, x                             // E374
    and #$40                                               // E377
    bne L_E37F                                             // E379
    stx ZP_OPCODE                                          // E37B
    beq L_E38A                                             // E37D

L_E37F:
    lda ZP_SUBMENU                                         // E37F
    beq EditProgramLoop                                    // E381
    ora #$80                                               // E383
    sta ZP_OPCODE                                          // E385
    jsr WaitForKeyOrTimer                                  // E387

L_E38A:
    jsr ReadOperandViaVector                               // E38A
    bcs L_E39D                                             // E38D
    ldx ZP_KEY                                             // E38F
    lda.abs RemoteActionMap, x                             // E391
    and #$40                                               // E394
    bne L_E35B                                             // E396
    jsr PlayErrorTone                                      // E398
    bmi EditProgramLoop                                    // E39B

L_E39D:
    lda ZP_PROGRAM_FLAGS                                   // E39D
    and #$bf                                               // E39F
    sta ZP_PROGRAM_FLAGS                                   // E3A1
    jsr PrepareProgramInsertion                            // E3A3
    jmp L_E349                                             // E3A6

// Clear/delete editing path. Uses program and temporary cursors.
ClearProgramStep:
    lda ZP_UI_FLAGS                                        // E3A9
    ora #$40                                               // E3AB
    sta ZP_UI_FLAGS                                        // E3AD
    lda #$00                                               // E3AF
    sta ZP_SUBMENU                                         // E3B1
    lda #$f4                                               // E3B3
    sta ZP_SPEED_GAME_TIMER                                // E3B5
    jsr RetreatProgramCursor                               // E3B7
    bcs L_E3C1                                             // E3BA
    jsr PlayFeedbackTone3C                                 // E3BC
    bmi WaitForKeyOrTimer                                  // E3BF

L_E3C1:
    jsr PlayFeedbackTone3C                                 // E3C1
    lda ZP_PROGRAM_CURSOR_LO                               // E3C4
    sta ZP_DISPLAY_EDIT_LO                                 // E3C6
    lda ZP_PROGRAM_CURSOR_HI                               // E3C8
    sta ZP_DISPLAY_EDIT_HI                                 // E3CA

L_E3CC:
    inc ZP_DISPLAY_EDIT_LO                                 // E3CC
    inc ZP_DISPLAY_EDIT_LO                                 // E3CE
    bne L_E3D4                                             // E3D0
    inc ZP_DISPLAY_EDIT_HI                                 // E3D2

L_E3D4:
    ldy #$81                                               // E3D4
    lda (ZP_DISPLAY_EDIT_LO), y                            // E3D6
    ldy #$7f                                               // E3D8
    sta (ZP_DISPLAY_EDIT_LO), y                            // E3DA
    iny                                                    // E3DC
    lda (ZP_DISPLAY_EDIT_LO), y                            // E3DD
    ldy #$7e                                               // E3DF
    sta (ZP_DISPLAY_EDIT_LO), y                            // E3E1
    cmp #$ff                                               // E3E3
    bne L_E3CC                                             // E3E5
    ldx #$0a                                               // E3E7
    jsr DisplayPreset                                      // E3E9

// Set $2A=$F4; return when remote mailbox is nonempty or the IRQ timer reaches zero.
WaitForKeyOrTimer:
    lda #$f4                                               // E3EC
    sta ZP_MOTOR_DELAY_TIMER                               // E3EE

L_E3F0:
    bit ZP_REMOTE_MAILBOX                                  // E3F0
    bpl L_E3F8                                             // E3F2
    lda ZP_MOTOR_DELAY_TIMER                               // E3F4
    bne L_E3F0                                             // E3F6

L_E3F8:
    rts                                                    // E3F8

// Move to an earlier command, subject to the beginning boundary.
ProgramBackstep:
    jsr RetreatProgramCursor                               // E3F9
    bcc L_E404                                             // E3FC
    jsr FetchProgramCommand                                // E3FE
    jsr DisplayCommandOperand                              // E401

L_E404:
    lda #$33                                               // E404
    jmp WaitForSpecificRemoteEvent                         // E406

// Fetch/display selected command and wait for the relevant key.
ExecuteSelectedStep:
    jsr FetchProgramCommand                                // E409
    jsr DisplayCommandOperand                              // E40C
    lda #$2f                                               // E40F
    jsr WaitForSpecificRemoteEvent                         // E411
    lda ZP_OPCODE                                          // E414
    cmp #$ff                                               // E416
    beq L_E422                                             // E418

// Increment biased 16-bit program cursor by two, carrying into its high byte.
AdvanceProgramCursor:
    inc ZP_PROGRAM_CURSOR_LO                               // E41A
    inc ZP_PROGRAM_CURSOR_LO                               // E41C
    bne L_E422                                             // E41E
    inc ZP_PROGRAM_CURSOR_HI                               // E420

L_E422:
    rts                                                    // E422

// Reset cursor, place $FF end marker, show clear-program preset.
ClearEntireProgram:
    jsr ResetProgramCursor                                 // E423
    jsr MarkProgramEnd                                     // E426
    ldx #$0b                                               // E429
    jsr DisplayPreset                                      // E42B
    jsr WaitForKeyOrTimer                                  // E42E
    jmp DisplayProgramPosition                             // E431

// Execute stored command pairs, handling reverse direction, delays, music and speech.
ExecuteProgram:
    lda #$01                                               // E434
    sta ZP_WHEEL_SPEED                                     // E436
    lda ZP_PROGRAM_FLAGS                                   // E438
    lsr                                                    // E43A
    bcs L_E460                                             // E43B
    sec                                                    // E43D
    rol                                                    // E43E
    tay                                                    // E43F
    and #$02                                               // E440
    beq L_E448                                             // E442
    tya                                                    // E444
    and #$bf                                               // E445
    tay                                                    // E447

L_E448:
    sty ZP_PROGRAM_FLAGS                                   // E448
    bit ZP_PROGRAM_FLAGS                                   // E44A
    bvc L_E45D                                             // E44C
    lda ZP_SAVED_DIRECTION                                 // E44E
    and #$01                                               // E450
    eor #$01                                               // E452
    sta ZP_MOTOR_DIRECTION                                 // E454

L_E456:
    jsr RetreatProgramCursor                               // E456
    bcs L_E460                                             // E459
    bcc L_E480                                             // E45B

L_E45D:
    jsr ResetProgramCursor                                 // E45D

L_E460:
    jsr DisplayProgramPosition                             // E460
    jsr FetchProgramCommand                                // E463
    cmp #$0c                                               // E466
    beq L_E472                                             // E468
    cmp #$ff                                               // E46A
    beq L_E472                                             // E46C
    lda ZP_PROGRAM_FLAGS                                   // E46E
    bmi L_E475                                             // E470

L_E472:
    jsr WaitForRobotActivities                             // E472

L_E475:
    lda ZP_OPCODE                                          // E475
    cmp #$ff                                               // E477
    bne L_E48C                                             // E479
    ldx #$0e                                               // E47B
    jsr DisplayPreset                                      // E47D

L_E480:
    jsr WaitForRobotActivities                             // E480
    lda ZP_PROGRAM_FLAGS                                   // E483
    eor #$41                                               // E485
    sta ZP_PROGRAM_FLAGS                                   // E487
    jmp (ZP_MODE_VECTOR)                                   // E489

L_E48C:
    jsr TransformReverseCommand                            // E48C

L_E48F:
    jsr PollRobotAndRemote                                 // E48F
    cpx #$0c                                               // E492
    bne L_E4AA                                             // E494
    jsr DisplayCommandOperand                              // E496

L_E499:
    jsr WaitForRemoteKey                                   // E499
    cmp #$0f                                               // E49C
    beq L_E4A5                                             // E49E
    jsr PlayErrorTone                                      // E4A0
    bmi L_E499                                             // E4A3

L_E4A5:
    lda #$2f                                               // E4A5
    jsr WaitForSpecificRemoteEvent                         // E4A7

L_E4AA:
    lda ZP_OPCODE                                          // E4AA
    cmp #$0c                                               // E4AC
    bne L_E4CC                                             // E4AE
    lda ZP_OPERAND                                         // E4B0
    beq L_E4F7                                             // E4B2
    sta ZP_DELAY_TIMER                                     // E4B4
    lda ZP_DELAY_TIMER                                     // E4B6
    beq L_E4F7                                             // E4B8

L_E4BA:
    bit ZP_TIMER_PHASE                                     // E4BA
    bpl L_E4BA                                             // E4BC

L_E4BE:
    bit ZP_TIMER_PHASE                                     // E4BE
    bmi L_E4BE                                             // E4C0
    lda ZP_DELAY_TIMER                                     // E4C2
    sta ZP_OPERAND                                         // E4C4
    jsr DisplayCommandOperand                              // E4C6
    jmp L_E48F                                             // E4C9

L_E4CC:
    tax                                                    // E4CC
    bmi L_E4DE                                             // E4CD
    and #$3f                                               // E4CF
    jsr ExecuteMotorCommand                                // E4D1
    lda ZP_MOTOR_DIRECTION                                 // E4D4
    sta ZP_SAVED_DIRECTION                                 // E4D6
    lda ZP_MOTION_RESULT                                   // E4D8
    bpl L_E4F7                                             // E4DA
    bmi L_E48F                                             // E4DC

L_E4DE:
    and #$0f                                               // E4DE
    cmp #$01                                               // E4E0
    bne L_E4F0                                             // E4E2
    lda ZP_MUSIC0_STATE                                    // E4E4
    bne L_E48F                                             // E4E6
    ldx ZP_OPERAND                                         // E4E8
    jsr SelectTune                                         // E4EA
    jmp L_E4F7                                             // E4ED

L_E4F0:
    lda ZP_SPEECH_STATE                                    // E4F0
    bne L_E48F                                             // E4F2
    jsr ExecuteSpeechCommand                               // E4F4

L_E4F7:
    bit ZP_PROGRAM_FLAGS                                   // E4F7
    bvc L_E4FE                                             // E4F9
    jmp L_E456                                             // E4FB

L_E4FE:
    jsr AdvanceProgramCursor                               // E4FE
    jmp L_E460                                             // E501

// Service robot until motor, speech, and music activity clears; stall/service paths can redirect control.
WaitForRobotActivities:
    jsr PollMotorProgressAndService                        // E504
    lda #$ff                                               // E507
    jsr ExecuteMotorCommand                                // E509
    lda ZP_CLAW_STATUS                                     // E50C
    and #$0c                                               // E50E
    ora ZP_MOTOR_STATUS                                    // E510
    ora ZP_SPEECH_STATE                                    // E512
    ora ZP_MUSIC0_STATE                                    // E514
    bne WaitForRobotActivities                             // E516
    rts                                                    // E518

// Read operand at cursor+$81, opcode at cursor+$80 into $13/$11; A returns opcode.
FetchProgramCommand:
    ldy #$81                                               // E519
    lda (ZP_PROGRAM_CURSOR_LO), y                          // E51B
    sta ZP_OPERAND                                         // E51D
    dey                                                    // E51F
    lda (ZP_PROGRAM_CURSOR_LO), y                          // E520
    sta ZP_OPCODE                                          // E522
    rts                                                    // E524

// Reverse-execution transformation for motion and open/close operands.
TransformReverseCommand:
    bit ZP_PROGRAM_FLAGS                                   // E525
    bvc L_E581                                             // E527
    ldx ZP_OPCODE                                          // E529
    cpx #$0b                                               // E52B
    bpl L_E538                                             // E52D
    lda.abs ReverseMotionMap, x                            // E52F
    cpx #$08                                               // E532
    bpl L_E539                                             // E534
    sta ZP_OPCODE                                          // E536

L_E538:
    rts                                                    // E538

L_E539:
    bne L_E547                                             // E539
    lda ZP_OPERAND                                         // E53B
    beq L_E546                                             // E53D
    sec                                                    // E53F
    lda #$55                                               // E540
    sbc ZP_OPERAND                                         // E542

L_E544:
    sta ZP_OPERAND                                         // E544

L_E546:
    rts                                                    // E546

L_E547:
    lda ZP_OPERAND                                         // E547
    eor #$01                                               // E549
    bpl L_E544                                             // E54B
.assert "10_modes_program end", *, $0e54d
