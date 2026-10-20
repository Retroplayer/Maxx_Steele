// Phrase editing, speech-port routines, IRQ service, vocabulary addresses and phrases
// Original CPU range $f378-$f64d.
.assert "40_speech start", *, $f378

// Select user phrase slot and write vocabulary codes/terminator into $0500 page.
EditSpeechPhrase:
    lda #$10                                               // F378
    sta ZP_OPCODE                                          // F37A
    jsr ReadOperandViaVector                               // F37C
    bcs L_F386                                             // F37F
    jsr PlayErrorTone                                      // F381
    bmi EditSpeechPhrase                                   // F384

L_F386:
    lda ZP_OPERAND                                         // F386
    asl                                                    // F388
    asl                                                    // F389
    asl                                                    // F38A
    asl                                                    // F38B
    sta ZP_SPEECH_PTR_LO                                   // F38C
    lda #>USER_PHRASES                                     // F38E
    sta ZP_SPEECH_PTR_HI                                   // F390
    ldy #$0f                                               // F392
    lda #$ff                                               // F394

L_F396:
    sta (ZP_SPEECH_PTR_LO), y                              // F396
    dey                                                    // F398
    bpl L_F396                                             // F399
    lda #$0e                                               // F39B
    sta ZP_OPCODE                                          // F39D

L_F39F:
    jsr ReadOperandViaVector                               // F39F
    bcs L_F3AA                                             // F3A2
    cpx #$0e                                               // F3A4
    beq L_F3C2                                             // F3A6
    bne L_F39F                                             // F3A8

L_F3AA:
    ldy #$00                                               // F3AA
    sta (ZP_SPEECH_PTR_LO), y                              // F3AC
    tax                                                    // F3AE
    jsr SpeakDirectSound                                   // F3AF
    jsr WaitForSpeech                                      // F3B2
    inc ZP_SPEECH_PTR_LO                                   // F3B5
    lda ZP_SPEECH_PTR_LO                                   // F3B7
    eor #$0f                                               // F3B9
    and #$0f                                               // F3BB
    bne L_F39F                                             // F3BD
    jmp (ZP_MODE_VECTOR)                                   // F3BF

L_F3C2:
    jsr PlayFeedbackTone3C                                 // F3C2
    lda ZP_SPEECH_PTR_LO                                   // F3C5
    and #$0f                                               // F3C7
    beq L_F39F                                             // F3C9
    dec ZP_SPEECH_PTR_LO                                   // F3CB
    ldy #$00                                               // F3CD
    lda #$ff                                               // F3CF
    sta (ZP_SPEECH_PTR_LO), y                              // F3D1
    bmi L_F39F                                             // F3D3

// Writable low-level vocabulary hook, initially SpeakVocabularyDefault.
SpeakVocabularyViaVector:
    jmp (ZP_SPEECH_VECTOR)                                 // F3D5

// X=vocabulary code; 140 is pause. Send external speech address via $1400, not CPU memory mapping.
SpeakVocabularyDefault:
    cpx #$8c                                               // F3D8
    beq L_F405                                             // F3DA
    lda #$00                                               // F3DC
    jsr SendSpeechNibble                                   // F3DE
    lda.abs SpeechAddressHi, x                             // F3E1
    jsr SendSpeechByte                                     // F3E4
    tya                                                    // F3E7
    jsr SendSpeechNibble                                   // F3E8
    lda.abs SpeechAddressLo, x                             // F3EB
    jsr SendSpeechByte                                     // F3EE
    tya                                                    // F3F1
    and #$0f                                               // F3F2
    ldy #$80                                               // F3F4
    sty ZP_SPEECH_LAUNCH                                   // F3F6
    tay                                                    // F3F8
    sta.abs IO_SPEECH_REMOTE                               // F3F9
    ora #$80                                               // F3FC
    sta.abs IO_SPEECH_REMOTE                               // F3FE
    sty.abs IO_SPEECH_REMOTE                               // F401
    rts                                                    // F404

L_F405:
    lda #$7a                                               // F405
    sta ZP_SPEECH_PAUSE                                    // F407
    lda #$40                                               // F409
    ora ZP_SPEECH_STATE                                    // F40B
    bne L_F439                                             // F40D

// X=phrase index; 0..15 use RAM slots, 16..32 scan ROM $FF-terminated token sequences.
SpeakPhrase:
    lda #$00                                               // F40F
    sta ZP_SPEECH_STATE                                    // F411
    txa                                                    // F413
    and #$f0                                               // F414
    bne L_F426                                             // F416
    txa                                                    // F418
    asl                                                    // F419
    asl                                                    // F41A
    asl                                                    // F41B
    asl                                                    // F41C
    sta ZP_SPEECH_PTR_LO                                   // F41D
    lda #>USER_PHRASES                                     // F41F
    sta ZP_SPEECH_PTR_HI                                   // F421
    jmp L_F437                                             // F423

L_F426:
    lda #<PhraseHelloIntro                                 // F426
    sta ZP_SPEECH_PTR_LO                                   // F428
    lda #>PhraseHelloIntro                                 // F42A
    sta ZP_SPEECH_PTR_HI                                   // F42C
    ldy #$00                                               // F42E
    txa                                                    // F430
    sec                                                    // F431
    sbc #$10                                               // F432
    tax                                                    // F434

L_F435:
    bne L_F43C                                             // F435

L_F437:
    lda #$80                                               // F437

L_F439:
    sta ZP_SPEECH_STATE                                    // F439
    rts                                                    // F43B

L_F43C:
    lda (ZP_SPEECH_PTR_LO), y                              // F43C
    inc ZP_SPEECH_PTR_LO                                   // F43E
    bne L_F444                                             // F440
    inc ZP_SPEECH_PTR_HI                                   // F442

L_F444:
    cmp #$ff                                               // F444
    bne L_F43C                                             // F446
    dex                                                    // F448
    bpl L_F435                                             // F449

// Dispatch stored sound/sentence operation using current opcode and operand.
ExecuteSpeechCommand:
    ldx ZP_OPERAND                                         // F44B
    lda ZP_OPCODE                                          // F44D
    cmp #$82                                               // F44F
    bne SpeakPhrase                                        // F451

// Prepare direct-sound state and invoke vocabulary dispatch.
SpeakDirectSound:
    lda #$00                                               // F453
    sta ZP_SPEECH_STATE                                    // F455
    jsr SpeakVocabularyViaVector                           // F457
    lda #$20                                               // F45A
    ora ZP_SPEECH_STATE                                    // F45C
    bne L_F439                                             // F45E

// Send high nibble first, then leave low nibble in Y for caller.
SendSpeechByte:
    tay                                                    // F460
    lsr                                                    // F461
    lsr                                                    // F462
    lsr                                                    // F463
    lsr                                                    // F464

// A=nibble; write data, strobe bit 4 high, then low.
SendSpeechNibble:
    and #$0f                                               // F465
    sta.abs IO_SPEECH_REMOTE                               // F467
    ora #$10                                               // F46A
    sta.abs IO_SPEECH_REMOTE                               // F46C
    and #$ef                                               // F46F
    sta.abs IO_SPEECH_REMOTE                               // F471
    rts                                                    // F474

// Feature bit 1 suppresses verbal prompts; programmed speech is a separate path.
SpeakPromptUnlessDisabled:
    lda #$02                                               // F475
    bit ZP_FEATURE_FLAGS                                   // F477
    bne L_F482                                             // F479
    jsr SpeakPhrase                                        // F47B

// Wait for speech state to clear; playback depends on IRQ service.
WaitForSpeech:
    lda ZP_SPEECH_STATE                                    // F47E
    bne WaitForSpeech                                      // F480

L_F482:
    rts                                                    // F482

// IRQ slot 7: busy/ready handling, phrase advancement, software pause, lamp updates.
SpeechIRQ:
    bit.abs IO_COP_CONTROL_STATUS                          // F483; N tests speech-ready/busy input bit 7
    bpl L_F4B5                                             // F486
    bit ZP_SPEECH_LAUNCH                                   // F488
    bmi L_F4D8                                             // F48A
    lda #$20                                               // F48C
    bit ZP_SPEECH_STATE                                    // F48E
    bvc L_F49C                                             // F490
    dec ZP_SPEECH_PAUSE                                    // F492
    bne L_F4D8                                             // F494
    lda ZP_SPEECH_STATE                                    // F496
    and #$bf                                               // F498
    bvs L_F4D6                                             // F49A

L_F49C:
    bne L_F4D1                                             // F49C
    bpl L_F4D8                                             // F49E
    ldy #$00                                               // F4A0
    lda (ZP_SPEECH_PTR_LO), y                              // F4A2
    inc ZP_SPEECH_PTR_LO                                   // F4A4
    bne L_F4AA                                             // F4A6
    inc ZP_SPEECH_PTR_HI                                   // F4A8

L_F4AA:
    cmp #$ff                                               // F4AA
    beq L_F4D1                                             // F4AC
    tax                                                    // F4AE
    jsr SpeakVocabularyViaVector                           // F4AF
    jmp L_F4D8                                             // F4B2

L_F4B5:
    dec ZP_SPEECH_LAMP_DIVIDER                             // F4B5
    bne L_F4CB                                             // F4B7
    lda #$10                                               // F4B9
    sta ZP_SPEECH_LAMP_DIVIDER                             // F4BB
    lda ZP_SPEECH_LAMP_PATTERN                             // F4BD
    sta.abs IO_LAMPS_ALARM_BATTERY                         // F4BF
    asl                                                    // F4C2
    eor ZP_SPEECH_LAMP_PATTERN                             // F4C3
    eor #$ff                                               // F4C5
    asl                                                    // F4C7
    asl                                                    // F4C8
    rol ZP_SPEECH_LAMP_PATTERN                             // F4C9

L_F4CB:
    lda #$00                                               // F4CB
    sta ZP_SPEECH_LAUNCH                                   // F4CD
    bpl L_F4D8                                             // F4CF

L_F4D1:
    lda #$00                                               // F4D1
    sta.abs IO_LAMPS_ALARM_BATTERY                         // F4D3

L_F4D6:
    sta ZP_SPEECH_STATE                                    // F4D6

L_F4D8:
    jmp IRQRestore                                         // F4D8

SpeechAddressLo:
    .byte <SPADDR_ZERO // F4DB; Vocabulary 0: zero
    .byte <SPADDR_ONE // F4DC; Vocabulary 1: one
    .byte <SPADDR_TWO // F4DD; Vocabulary 2: two
    .byte <SPADDR_THREE // F4DE; Vocabulary 3: three
    .byte <SPADDR_FOUR // F4DF; Vocabulary 4: four
    .byte <SPADDR_FIVE // F4E0; Vocabulary 5: five
    .byte <SPADDR_SIX // F4E1; Vocabulary 6: six
    .byte <SPADDR_SEVEN // F4E2; Vocabulary 7: seven
    .byte <SPADDR_EIGHT // F4E3; Vocabulary 8: eight
    .byte <SPADDR_NINE // F4E4; Vocabulary 9: nine
    .byte <SPADDR_TEN // F4E5; Vocabulary 10: ten
    .byte <SPADDR_ELEVEN // F4E6; Vocabulary 11: eleven
    .byte <SPADDR_TWELVE // F4E7; Vocabulary 12: twelve
    .byte <SPADDR_THIR // F4E8; Vocabulary 13: thir
    .byte <SPADDR_FIF // F4E9; Vocabulary 14: fif
    .byte <SPADDR_TEEN // F4EA; Vocabulary 15: teen
    .byte <SPADDR_TWEN // F4EB; Vocabulary 16: twen
    .byte <SPADDR_TY // F4EC; Vocabulary 17: ty
    .byte <SPADDR_HUNDRED // F4ED; Vocabulary 18: hundred
    .byte <SPADDR_A // F4EE; Vocabulary 19: a
    .byte <SPADDR_ACCEPTED // F4EF; Vocabulary 20: accepted
    .byte <SPADDR_AGAIN // F4F0; Vocabulary 21: again
    .byte <SPADDR_AH // F4F1; Vocabulary 22: ah
    .byte <SPADDR_AID // F4F2; Vocabulary 23: aid
    .byte <SPADDR_AIM // F4F3; Vocabulary 24: aim
    .byte <SPADDR_AM // F4F4; Vocabulary 25: am
    .byte <SPADDR_AN // F4F5; Vocabulary 26: an
    .byte <SPADDR_AND // F4F6; Vocabulary 27: and
    .byte <SPADDR_ANY // F4F7; Vocabulary 28: any
    .byte <SPADDR_APPROACH // F4F8; Vocabulary 29: approach
    .byte <SPADDR_ARE // F4F9; Vocabulary 30: are
    .byte <SPADDR_AWE // F4FA; Vocabulary 31: awe
    .byte <SPADDR_BE // F4FB; Vocabulary 32: be
    .byte <SPADDR_BEGIN // F4FC; Vocabulary 33: begin
    .byte <SPADDR_BOOST // F4FD; Vocabulary 34: boost
    .byte <SPADDR_BOUT // F4FE; Vocabulary 35: bout
    .byte <SPADDR_BUT // F4FF; Vocabulary 36: but
    .byte <SPADDR_BY // F500; Vocabulary 37: by
    .byte <SPADDR_CAN // F501; Vocabulary 38: can
    .byte <SPADDR_CHARGE // F502; Vocabulary 39: charge
    .byte <SPADDR_CHOICE // F503; Vocabulary 40: choice
    .byte <SPADDR_CHOOSE // F504; Vocabulary 41: choose
    .byte <SPADDR_CIRCUITS // F505; Vocabulary 42: circuits
    .byte <SPADDR_CLEAR // F506; Vocabulary 43: clear
    .byte <SPADDR_CONGRATULATIONS // F507; Vocabulary 44: congratulations
    .byte <SPADDR_CORDED // F508; Vocabulary 45: corded
    .byte <SPADDR_DAY // F509; Vocabulary 46: day
    .byte <SPADDR_DEAD // F50A; Vocabulary 47: dead
    .byte <SPADDR_DIFFERENT // F50B; Vocabulary 48: different
    .byte <SPADDR_DO // F50C; Vocabulary 49: do
    .byte <SPADDR_EAR // F50D; Vocabulary 50: ear
    .byte <SPADDR_EASY // F50E; Vocabulary 51: easy
    .byte <SPADDR_ENERGY // F50F; Vocabulary 52: energy
    .byte <SPADDR_ENTER // F510; Vocabulary 53: enter
    .byte <SPADDR_ERROR // F511; Vocabulary 54: error
    .byte <SPADDR_EST // F512; Vocabulary 55: est
    .byte <SPADDR_FUNCTION // F513; Vocabulary 56: function
    .byte <SPADDR_FULL // F514; Vocabulary 57: full
    .byte <SPADDR_GAME // F515; Vocabulary 58: game
    .byte <SPADDR_GET // F516; Vocabulary 59: get
    .byte <SPADDR_GOES // F517; Vocabulary 60: goes
    .byte <SPADDR_GOOD // F518; Vocabulary 61: good
    .byte <SPADDR_GREAT // F519; Vocabulary 62: great
    .byte <SPADDR_HAHAHAHAHA // F51A; Vocabulary 63: hahahahaha
    .byte <SPADDR_HAVE // F51B; Vocabulary 64: have
    .byte <SPADDR_HELLO // F51C; Vocabulary 65: hello
    .byte <SPADDR_HOW // F51D; Vocabulary 66: how
    .byte <SPADDR_HUMAN // F51E; Vocabulary 67: human
    .byte <SPADDR_I // F51F; Vocabulary 68: I
    .byte <SPADDR_IF // F520; Vocabulary 69: if
    .byte <SPADDR_I_M // F521; Vocabulary 70: I'm
    .byte <SPADDR_IN // F522; Vocabulary 71: in
    .byte <SPADDR_INDICATE // F523; Vocabulary 72: indicate
    .byte <SPADDR_ING // F524; Vocabulary 73: ing
    .byte <SPADDR_IS // F525; Vocabulary 74: is
    .byte <SPADDR_IT // F526; Vocabulary 75: it
    .byte <SPADDR_JUST // F527; Vocabulary 76: just
    .byte <SPADDR_LAY // F528; Vocabulary 77: lay
    .byte <SPADDR_LET // F529; Vocabulary 78: let
    .byte <SPADDR_LIKED // F52A; Vocabulary 79: liked
    .byte <SPADDR_LOAD // F52B; Vocabulary 80: load
    .byte <SPADDR_LONG // F52C; Vocabulary 81: long
    .byte <SPADDR_MADE // F52D; Vocabulary 82: made
    .byte <SPADDR_MATCH // F52E; Vocabulary 83: match
    .byte <SPADDR_MAX // F52F; Vocabulary 84: max
    .byte <SPADDR_ME // F530; Vocabulary 85: me
    .byte <SPADDR_MORN // F531; Vocabulary 86: morn
    .byte <SPADDR_MY // F532; Vocabulary 87: my
    .byte <SPADDR_NAME // F533; Vocabulary 88: name
    .byte <SPADDR_NEED // F534; Vocabulary 89: need
    .byte <SPADDR_NO // F535; Vocabulary 90: no
    .byte <SPADDR_NOW // F536; Vocabulary 91: now
    .byte <SPADDR_OK // F537; Vocabulary 92: ok
    .byte <SPADDR_OPPONENT // F538; Vocabulary 93: opponent
    .byte <SPADDR_OR // F539; Vocabulary 94: or
    .byte <SPADDR_OUT // F53A; Vocabulary 95: out
    .byte <SPADDR_OVER // F53B; Vocabulary 96: over
    .byte <SPADDR_OW // F53C; Vocabulary 97: ow
    .byte <SPADDR_PAL // F53D; Vocabulary 98: pal
    .byte <SPADDR_PLAY // F53E; Vocabulary 99: play
    .byte <SPADDR_PLEASE // F53F; Vocabulary 100: please
    .byte <SPADDR_PROGRAM // F540; Vocabulary 101: program
    .byte <SPADDR_PROPER // F541; Vocabulary 102: proper
    .byte <SPADDR_RE // F542; Vocabulary 103: re
    .byte <SPADDR_READY // F543; Vocabulary 104: ready
    .byte <SPADDR_RUN // F544; Vocabulary 105: run
    .byte <SPADDR_SERVE // F545; Vocabulary 106: serve
    .byte <SPADDR_SOME // F546; Vocabulary 107: some
    .byte <SPADDR_SORRY // F547; Vocabulary 108: sorry
    .byte <SPADDR_SSS // F548; Vocabulary 109: sss
    .byte <SPADDR_STEELE // F549; Vocabulary 110: steele
    .byte <SPADDR_SUPPOSE // F54A; Vocabulary 111: suppose
    .byte <SPADDR_SURE // F54B; Vocabulary 112: sure
    .byte <SPADDR_TEACH // F54C; Vocabulary 113: teach
    .byte <SPADDR_TEST // F54D; Vocabulary 114: test
    .byte <SPADDR_THANK // F54E; Vocabulary 115: thank
    .byte <SPADDR_THAT // F54F; Vocabulary 116: that
    .byte <SPADDR_THE // F550; Vocabulary 117: the
    .byte <SPADDR_THERE // F551; Vocabulary 118: there
    .byte <SPADDR_THING // F552; Vocabulary 119: thing
    .byte <SPADDR_TIME // F553; Vocabulary 120: time
    .byte <SPADDR_TOUGH // F554; Vocabulary 121: tough
    .byte <SPADDR_TRY // F555; Vocabulary 122: try
    .byte <SPADDR_TURN // F556; Vocabulary 123: turn
    .byte <SPADDR_UP // F557; Vocabulary 124: up
    .byte <SPADDR_UPPER // F558; Vocabulary 125: upper
    .byte <SPADDR_WAIT // F559; Vocabulary 126: wait
    .byte <SPADDR_WAS // F55A; Vocabulary 127: was
    .byte <SPADDR_WAY // F55B; Vocabulary 128: way
    .byte <SPADDR_WERE // F55C; Vocabulary 129: were
    .byte <SPADDR_WHAT // F55D; Vocabulary 130: what
    .byte <SPADDR_WHEN // F55E; Vocabulary 131: when
    .byte <SPADDR_WHO // F55F; Vocabulary 132: who
    .byte <SPADDR_WHOOPS // F560; Vocabulary 133: whoops
    .byte <SPADDR_WILL // F561; Vocabulary 134: will
    .byte <SPADDR_WIN // F562; Vocabulary 135: win
    .byte <SPADDR_WOULD // F563; Vocabulary 136: would
    .byte <SPADDR_YES // F564; Vocabulary 137: yes
    .byte <SPADDR_YOU // F565; Vocabulary 138: you
    .byte <SPADDR_ZZ // F566; Vocabulary 139: zz

SpeechAddressHi:
    .byte >SPADDR_ZERO // F567; Vocabulary 0: zero
    .byte >SPADDR_ONE // F568; Vocabulary 1: one
    .byte >SPADDR_TWO // F569; Vocabulary 2: two
    .byte >SPADDR_THREE // F56A; Vocabulary 3: three
    .byte >SPADDR_FOUR // F56B; Vocabulary 4: four
    .byte >SPADDR_FIVE // F56C; Vocabulary 5: five
    .byte >SPADDR_SIX // F56D; Vocabulary 6: six
    .byte >SPADDR_SEVEN // F56E; Vocabulary 7: seven
    .byte >SPADDR_EIGHT // F56F; Vocabulary 8: eight
    .byte >SPADDR_NINE // F570; Vocabulary 9: nine
    .byte >SPADDR_TEN // F571; Vocabulary 10: ten
    .byte >SPADDR_ELEVEN // F572; Vocabulary 11: eleven
    .byte >SPADDR_TWELVE // F573; Vocabulary 12: twelve
    .byte >SPADDR_THIR // F574; Vocabulary 13: thir
    .byte >SPADDR_FIF // F575; Vocabulary 14: fif
    .byte >SPADDR_TEEN // F576; Vocabulary 15: teen
    .byte >SPADDR_TWEN // F577; Vocabulary 16: twen
    .byte >SPADDR_TY // F578; Vocabulary 17: ty
    .byte >SPADDR_HUNDRED // F579; Vocabulary 18: hundred
    .byte >SPADDR_A // F57A; Vocabulary 19: a
    .byte >SPADDR_ACCEPTED // F57B; Vocabulary 20: accepted
    .byte >SPADDR_AGAIN // F57C; Vocabulary 21: again
    .byte >SPADDR_AH // F57D; Vocabulary 22: ah
    .byte >SPADDR_AID // F57E; Vocabulary 23: aid
    .byte >SPADDR_AIM // F57F; Vocabulary 24: aim
    .byte >SPADDR_AM // F580; Vocabulary 25: am
    .byte >SPADDR_AN // F581; Vocabulary 26: an
    .byte >SPADDR_AND // F582; Vocabulary 27: and
    .byte >SPADDR_ANY // F583; Vocabulary 28: any
    .byte >SPADDR_APPROACH // F584; Vocabulary 29: approach
    .byte >SPADDR_ARE // F585; Vocabulary 30: are
    .byte >SPADDR_AWE // F586; Vocabulary 31: awe
    .byte >SPADDR_BE // F587; Vocabulary 32: be
    .byte >SPADDR_BEGIN // F588; Vocabulary 33: begin
    .byte >SPADDR_BOOST // F589; Vocabulary 34: boost
    .byte >SPADDR_BOUT // F58A; Vocabulary 35: bout
    .byte >SPADDR_BUT // F58B; Vocabulary 36: but
    .byte >SPADDR_BY // F58C; Vocabulary 37: by
    .byte >SPADDR_CAN // F58D; Vocabulary 38: can
    .byte >SPADDR_CHARGE // F58E; Vocabulary 39: charge
    .byte >SPADDR_CHOICE // F58F; Vocabulary 40: choice
    .byte >SPADDR_CHOOSE // F590; Vocabulary 41: choose
    .byte >SPADDR_CIRCUITS // F591; Vocabulary 42: circuits
    .byte >SPADDR_CLEAR // F592; Vocabulary 43: clear
    .byte >SPADDR_CONGRATULATIONS // F593; Vocabulary 44: congratulations
    .byte >SPADDR_CORDED // F594; Vocabulary 45: corded
    .byte >SPADDR_DAY // F595; Vocabulary 46: day
    .byte >SPADDR_DEAD // F596; Vocabulary 47: dead
    .byte >SPADDR_DIFFERENT // F597; Vocabulary 48: different
    .byte >SPADDR_DO // F598; Vocabulary 49: do
    .byte >SPADDR_EAR // F599; Vocabulary 50: ear
    .byte >SPADDR_EASY // F59A; Vocabulary 51: easy
    .byte >SPADDR_ENERGY // F59B; Vocabulary 52: energy
    .byte >SPADDR_ENTER // F59C; Vocabulary 53: enter
    .byte >SPADDR_ERROR // F59D; Vocabulary 54: error
    .byte >SPADDR_EST // F59E; Vocabulary 55: est
    .byte >SPADDR_FUNCTION // F59F; Vocabulary 56: function
    .byte >SPADDR_FULL // F5A0; Vocabulary 57: full
    .byte >SPADDR_GAME // F5A1; Vocabulary 58: game
    .byte >SPADDR_GET // F5A2; Vocabulary 59: get
    .byte >SPADDR_GOES // F5A3; Vocabulary 60: goes
    .byte >SPADDR_GOOD // F5A4; Vocabulary 61: good
    .byte >SPADDR_GREAT // F5A5; Vocabulary 62: great
    .byte >SPADDR_HAHAHAHAHA // F5A6; Vocabulary 63: hahahahaha
    .byte >SPADDR_HAVE // F5A7; Vocabulary 64: have
    .byte >SPADDR_HELLO // F5A8; Vocabulary 65: hello
    .byte >SPADDR_HOW // F5A9; Vocabulary 66: how
    .byte >SPADDR_HUMAN // F5AA; Vocabulary 67: human
    .byte >SPADDR_I // F5AB; Vocabulary 68: I
    .byte >SPADDR_IF // F5AC; Vocabulary 69: if
    .byte >SPADDR_I_M // F5AD; Vocabulary 70: I'm
    .byte >SPADDR_IN // F5AE; Vocabulary 71: in
    .byte >SPADDR_INDICATE // F5AF; Vocabulary 72: indicate
    .byte >SPADDR_ING // F5B0; Vocabulary 73: ing
    .byte >SPADDR_IS // F5B1; Vocabulary 74: is
    .byte >SPADDR_IT // F5B2; Vocabulary 75: it
    .byte >SPADDR_JUST // F5B3; Vocabulary 76: just
    .byte >SPADDR_LAY // F5B4; Vocabulary 77: lay
    .byte >SPADDR_LET // F5B5; Vocabulary 78: let
    .byte >SPADDR_LIKED // F5B6; Vocabulary 79: liked
    .byte >SPADDR_LOAD // F5B7; Vocabulary 80: load
    .byte >SPADDR_LONG // F5B8; Vocabulary 81: long
    .byte >SPADDR_MADE // F5B9; Vocabulary 82: made
    .byte >SPADDR_MATCH // F5BA; Vocabulary 83: match
    .byte >SPADDR_MAX // F5BB; Vocabulary 84: max
    .byte >SPADDR_ME // F5BC; Vocabulary 85: me
    .byte >SPADDR_MORN // F5BD; Vocabulary 86: morn
    .byte >SPADDR_MY // F5BE; Vocabulary 87: my
    .byte >SPADDR_NAME // F5BF; Vocabulary 88: name
    .byte >SPADDR_NEED // F5C0; Vocabulary 89: need
    .byte >SPADDR_NO // F5C1; Vocabulary 90: no
    .byte >SPADDR_NOW // F5C2; Vocabulary 91: now
    .byte >SPADDR_OK // F5C3; Vocabulary 92: ok
    .byte >SPADDR_OPPONENT // F5C4; Vocabulary 93: opponent
    .byte >SPADDR_OR // F5C5; Vocabulary 94: or
    .byte >SPADDR_OUT // F5C6; Vocabulary 95: out
    .byte >SPADDR_OVER // F5C7; Vocabulary 96: over
    .byte >SPADDR_OW // F5C8; Vocabulary 97: ow
    .byte >SPADDR_PAL // F5C9; Vocabulary 98: pal
    .byte >SPADDR_PLAY // F5CA; Vocabulary 99: play
    .byte >SPADDR_PLEASE // F5CB; Vocabulary 100: please
    .byte >SPADDR_PROGRAM // F5CC; Vocabulary 101: program
    .byte >SPADDR_PROPER // F5CD; Vocabulary 102: proper
    .byte >SPADDR_RE // F5CE; Vocabulary 103: re
    .byte >SPADDR_READY // F5CF; Vocabulary 104: ready
    .byte >SPADDR_RUN // F5D0; Vocabulary 105: run
    .byte >SPADDR_SERVE // F5D1; Vocabulary 106: serve
    .byte >SPADDR_SOME // F5D2; Vocabulary 107: some
    .byte >SPADDR_SORRY // F5D3; Vocabulary 108: sorry
    .byte >SPADDR_SSS // F5D4; Vocabulary 109: sss
    .byte >SPADDR_STEELE // F5D5; Vocabulary 110: steele
    .byte >SPADDR_SUPPOSE // F5D6; Vocabulary 111: suppose
    .byte >SPADDR_SURE // F5D7; Vocabulary 112: sure
    .byte >SPADDR_TEACH // F5D8; Vocabulary 113: teach
    .byte >SPADDR_TEST // F5D9; Vocabulary 114: test
    .byte >SPADDR_THANK // F5DA; Vocabulary 115: thank
    .byte >SPADDR_THAT // F5DB; Vocabulary 116: that
    .byte >SPADDR_THE // F5DC; Vocabulary 117: the
    .byte >SPADDR_THERE // F5DD; Vocabulary 118: there
    .byte >SPADDR_THING // F5DE; Vocabulary 119: thing
    .byte >SPADDR_TIME // F5DF; Vocabulary 120: time
    .byte >SPADDR_TOUGH // F5E0; Vocabulary 121: tough
    .byte >SPADDR_TRY // F5E1; Vocabulary 122: try
    .byte >SPADDR_TURN // F5E2; Vocabulary 123: turn
    .byte >SPADDR_UP // F5E3; Vocabulary 124: up
    .byte >SPADDR_UPPER // F5E4; Vocabulary 125: upper
    .byte >SPADDR_WAIT // F5E5; Vocabulary 126: wait
    .byte >SPADDR_WAS // F5E6; Vocabulary 127: was
    .byte >SPADDR_WAY // F5E7; Vocabulary 128: way
    .byte >SPADDR_WERE // F5E8; Vocabulary 129: were
    .byte >SPADDR_WHAT // F5E9; Vocabulary 130: what
    .byte >SPADDR_WHEN // F5EA; Vocabulary 131: when
    .byte >SPADDR_WHO // F5EB; Vocabulary 132: who
    .byte >SPADDR_WHOOPS // F5EC; Vocabulary 133: whoops
    .byte >SPADDR_WILL // F5ED; Vocabulary 134: will
    .byte >SPADDR_WIN // F5EE; Vocabulary 135: win
    .byte >SPADDR_WOULD // F5EF; Vocabulary 136: would
    .byte >SPADDR_YES // F5F0; Vocabulary 137: yes
    .byte >SPADDR_YOU // F5F1; Vocabulary 138: you
    .byte >SPADDR_ZZ // F5F2; Vocabulary 139: zz

PhraseHelloIntro:
    .byte VOC_HELLO, VOC_PAUSE, VOC_I, VOC_AM, VOC_MAX, VOC_STEELE, VOC_PAUSE, $ff // F5F3; Phrase 16: hello [pause] I am max steele [pause]

PhraseChooseDifficulty:
    .byte VOC_PLEASE, VOC_CHOOSE, VOC_HOW, VOC_TOUGH, $ff // F5FB; Phrase 17: please choose how tough

PhraseChooseGame:
    .byte VOC_PLEASE, VOC_CHOOSE, VOC_GAME, $ff // F600; Phrase 18: please choose game

PhraseGoodPlay:
    .byte VOC_GOOD, VOC_PLAY, $ff // F604; Phrase 19: good play

PhraseThankYou:
    .byte VOC_THANK, VOC_YOU, $ff // F607; Phrase 20: thank you

PhraseCanIHelp:
    .byte VOC_IS, VOC_THERE, VOC_ANY, VOC_THING, VOC_I, VOC_CAN, VOC_DO, VOC_FOUR, VOC_YOU, $ff // F60A; Phrase 21: is there any thing I can do four you

PhraseGoodMorning:
    .byte VOC_GOOD, VOC_MORN, VOC_ING, $ff // F614; Phrase 22: good morn ing

PhraseTimeToGetUp:
    .byte VOC_IT, VOC_IS, VOC_TIME, VOC_TWO, VOC_GET, VOC_UP, $ff // F618; Phrase 23: it is time two get up

PhraseMaxxWins:
    .byte VOC_MAX, VOC_STEELE, VOC_WIN, VOC_ZZ, $ff // F61F; Phrase 24: max steele win zz

PhraseYouWin:
    .byte VOC_CONGRATULATIONS, VOC_PAUSE, VOC_YOU, VOC_WIN, $ff // F624; Phrase 25: congratulations [pause] you win

PhraseRechargeBattery:
    .byte VOC_I, VOC_NEED, VOC_ENERGY, VOC_PAUSE, VOC_PLEASE, VOC_RE, VOC_CHARGE, VOC_ME, $ff // F629; Phrase 26: I need energy [pause] please re charge me

PhraseGameOver:
    .byte VOC_GAME, VOC_OVER, VOC_PAUSE, $ff // F632; Phrase 27: game over [pause]

PhrasePlayAgain:
    .byte VOC_CHOOSE, VOC_ENTER, VOC_TWO, VOC_PLAY, VOC_AGAIN, $ff // F636; Phrase 28: choose enter two play again

PhraseCircuitsFull:
    .byte VOC_SORRY, VOC_PAUSE, VOC_MY, VOC_CIRCUITS, VOC_ARE, VOC_FULL, $ff // F63C; Phrase 29: sorry [pause] my circuits are full

PhraseTeachMe:
    .byte VOC_PLEASE, VOC_TEACH, VOC_ME, $ff // F643; Phrase 30: please teach me

PhraseProgramMe:
    .byte VOC_PLEASE, VOC_PROGRAM, VOC_ME, $ff // F647; Phrase 31: please program me

PhraseReady:
    .byte VOC_I_M, VOC_READY, $ff // F64B; Phrase 32: I'm ready
.assert "40_speech end", *, $0f64e
