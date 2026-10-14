// Motor progress checks, service vector, sleep, timers, and headlamp IRQ
// Original CPU range $edaf-$eee9.
.assert "22_service_power start", *, $edaf

// When timer allows: B1/B0 then active counters. Equal consecutive count enters stall path.
PollMotorProgressAndService:
    lda ZP_STALL_TIMER                                     // EDAF
    beq L_EDB6                                             // EDB1
    jmp ServiceViaVector                                   // EDB3

L_EDB6:
    lda #$b1                                               // EDB6
    jsr ReadMotorReply                                     // EDB8
    sta ZP_CLAW_STATUS                                     // EDBB
    lda #$b0                                               // EDBD
    jsr ReadMotorReply                                     // EDBF
    sta ZP_MOTOR_STATUS                                    // EDC2
    and ZP_PRIOR_MOTOR_STATUS                              // EDC4
    and #$0f                                               // EDC6
    beq L_EDD5                                             // EDC8
    lda #$84                                               // EDCA
    jsr ReadMotorReply                                     // EDCC
    cmp ZP_WHEEL_LAST_COUNT                                // EDCF
    beq HandleMotorStall                                   // EDD1
    sta ZP_WHEEL_LAST_COUNT                                // EDD3

L_EDD5:
    lda ZP_PRIOR_MOTOR_STATUS                              // EDD5
    and ZP_MOTOR_STATUS                                    // EDD7
    and #$30                                               // EDD9
    beq L_EDE8                                             // EDDB
    lda #$82                                               // EDDD
    jsr ReadMotorReply                                     // EDDF
    cmp ZP_WRIST_LAST_COUNT                                // EDE2
    beq HandleMotorStall                                   // EDE4
    sta ZP_WRIST_LAST_COUNT                                // EDE6

L_EDE8:
    lda ZP_PRIOR_MOTOR_STATUS                              // EDE8
    and ZP_MOTOR_STATUS                                    // EDEA
    and #$c0                                               // EDEC
    beq L_EDFB                                             // EDEE
    lda #$81                                               // EDF0
    jsr ReadMotorReply                                     // EDF2
    cmp ZP_ARM_LAST_COUNT                                  // EDF5
    beq HandleMotorStall                                   // EDF7
    sta ZP_ARM_LAST_COUNT                                  // EDF9

L_EDFB:
    lda ZP_PRIOR_CLAW_STATUS                               // EDFB
    and ZP_CLAW_STATUS                                     // EDFD
    and #$08                                               // EDFF
    beq L_EE0E                                             // EE01
    lda #$80                                               // EE03
    jsr ReadMotorReply                                     // EE05
    cmp ZP_CLAW_LAST_COUNT                                 // EE08
    beq HandleMotorStall                                   // EE0A
    sta ZP_CLAW_LAST_COUNT                                 // EE0C

L_EE0E:
    lda ZP_MOTOR_STATUS                                    // EE0E
    sta ZP_PRIOR_MOTOR_STATUS                              // EE10
    lda ZP_CLAW_STATUS                                     // EE12
    sta ZP_PRIOR_CLAW_STATUS                               // EE14
    lda #$02                                               // EE16
    sta ZP_STALL_TIMER                                     // EE18
    bne ServiceViaVector                                   // EE1A

// Stop motors, show StAL, increment diagnostic counter, sound error, return through mode vector.
HandleMotorStall:
    jsr StopAllMotors                                      // EE1C
    ldx #$0d                                               // EE1F
    jsr DisplayPreset                                      // EE21
    inc ZP_STALL_ERRORS                                    // EE24
    jsr PlayErrorTone                                      // EE26
    jsr WaitForKeyOrTimer                                  // EE29
    jmp (ZP_MODE_VECTOR)                                   // EE2C

// Indirect service hook, initially ServiceDefault.
ServiceViaVector:
    jmp (ZP_SERVICE_VECTOR)                                // EE2F

// Alarm response, inactivity power-down, and battery warning foreground service.
ServiceDefault:
    bit ZP_ALARM_FLAGS                                     // EE32
    bpl L_EE5B                                             // EE34
    bit.abs IO_LAMPS_ALARM_BATTERY                         // EE36; V tests alarm input bit 6
    bvs L_EE5B                                             // EE39
    lda #$00                                               // EE3B
    sta ZP_ALARM_FLAGS                                     // EE3D
    lda #$ee                                               // EE3F
    jsr SendHeadByte                                       // EE41
    lda ZP_MODE                                            // EE44
    bne L_EE53                                             // EE46
    lda #$10                                               // EE48
    bit ZP_FEATURE_FLAGS                                   // EE4A
    beq L_EE53                                             // EE4C
    lda #$03                                               // EE4E
    jmp EnterForegroundMode                                // EE50

L_EE53:
    ldx #$06                                               // EE53
    jsr SelectTune                                         // EE55
    jmp WaitForTune                                        // EE58

L_EE5B:
    lda ZP_MODE                                            // EE5B
    cmp #$03                                               // EE5D
    beq L_EE89                                             // EE5F
    cmp #$04                                               // EE61
    beq L_EE89                                             // EE63
    lda ZP_INACTIVITY_HI                                   // EE65
    cmp #$03                                               // EE67
    bcc L_EE89                                             // EE69
    ldx #$08                                               // EE6B
    jsr SelectTune                                         // EE6D

L_EE70:
    lda ZP_REMOTE_MAILBOX                                  // EE70
    bpl L_EE86                                             // EE72
    lda ZP_MUSIC0_STATE                                    // EE74
    bne L_EE70                                             // EE76

// SEI; write $02 to system control, send head sleep command, then loop. Wake mechanism is hardware-dependent.
EnterSleep:
    sei                                                    // EE78
    lda #$02                                               // EE79
    sta.abs IO_SYSTEM_CONTROL                              // EE7B
    lda #$e5                                               // EE7E
    jsr SendHeadByte                                       // EE80

L_EE83:
    jmp L_EE83                                             // EE83

L_EE86:
    jsr InitializeMusicVoices                              // EE86

L_EE89:
    lda ZP_BATTERY_STATE                                   // EE89
    bne L_EE94                                             // EE8B
    dec ZP_BATTERY_STATE                                   // EE8D
    ldx #$1a                                               // EE8F
    jmp SpeakPhrase                                        // EE91

L_EE94:
    rts                                                    // EE94

// IRQ task: periodic/inactivity/motor timers and battery status. Returns through IRQRestore.
TimerIRQ:
    dec ZP_TIMER_PHASE                                     // EE95
    bne L_EEC1                                             // EE97
    lda #$f4                                               // EE99
    sta ZP_TIMER_PHASE                                     // EE9B
    ldx ZP_BATTERY_STATE                                   // EE9D
    beq L_EEAB                                             // EE9F
    dex                                                    // EEA1
    bit.abs IO_LAMPS_ALARM_BATTERY                         // EEA2; N tests battery input bit 7
    bpl L_EEA9                                             // EEA5
    ldx #$ff                                               // EEA7

L_EEA9:
    stx ZP_BATTERY_STATE                                   // EEA9

L_EEAB:
    bit ZP_FEATURE_FLAGS                                   // EEAB
    bmi L_EEB5                                             // EEAD
    dec ZP_INACTIVITY_LO                                   // EEAF
    bne L_EEB5                                             // EEB1
    inc ZP_INACTIVITY_HI                                   // EEB3

L_EEB5:
    lda ZP_DELAY_TIMER                                     // EEB5
    beq L_EEBB                                             // EEB7
    dec ZP_DELAY_TIMER                                     // EEB9

L_EEBB:
    lda ZP_STALL_TIMER                                     // EEBB
    beq L_EEC1                                             // EEBD
    dec ZP_STALL_TIMER                                     // EEBF

L_EEC1:
    lda ZP_SPEED_GAME_TIMER                                // EEC1
    beq L_EEC7                                             // EEC3
    dec ZP_SPEED_GAME_TIMER                                // EEC5

L_EEC7:
    lda ZP_MOTOR_DELAY_TIMER                               // EEC7
    beq L_EECD                                             // EEC9
    dec ZP_MOTOR_DELAY_TIMER                               // EECB

L_EECD:
    jmp IRQRestore                                         // EECD

// IRQ task: headlamp shadow/divider and output at $1000. Returns through IRQRestore.
HeadlampIRQ:
    bit ZP_HEADLAMP_STATE                                  // EED0
    bvs L_EED8                                             // EED2
    lda #$00                                               // EED4
    beq L_EEE2                                             // EED6

L_EED8:
    dec ZP_HEADLAMP_DIVIDER                                // EED8
    bmi L_EEE7                                             // EEDA
    lda #$82                                               // EEDC
    sta ZP_HEADLAMP_DIVIDER                                // EEDE
    eor ZP_HEADLAMP_STATE                                  // EEE0

L_EEE2:
    sta.abs IO_SERIAL_STATUS_HEADLAMP                      // EEE2
    sta ZP_HEADLAMP_STATE                                  // EEE5

L_EEE7:
    jmp IRQRestore                                         // EEE7
.assert "22_service_power end", *, $0eeea
