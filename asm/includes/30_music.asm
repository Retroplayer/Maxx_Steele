// Tune editing/playback, tone programming, and IRQ music effects
// Original CPU range $eeea-$f377.
.assert "30_music start", *, $eeea

// Clear effect mask then continue to voice initialization.
ClearMusicEffectsAndInitialize:
    lda #$00                                               // EEEA
    sta ZP_MUSIC_EFFECT_MASK                               // EEEC

// Reset voice state and mute channels; called by reset before cartridge dispatch.
InitializeMusicVoices:
    ldx #$03                                               // EEEE

L_EEF0:
    lda #$00                                               // EEF0
    sta ZP_MUSIC0_STATE, x                                 // EEF2
    sta ZP_MUSIC2_STATE                                    // EEF4
    sta ZP_MUSIC_EDIT_FLAGS                                // EEF6
    jsr MuteSelectedMusicVoice                             // EEF8
    dex                                                    // EEFB
    bpl L_EEF0                                             // EEFC
    rts                                                    // EEFE
    ldx #$07                                               // EEFF

// X=tune index 0..8; load six split stream-pointer bytes and activate voice state.
SelectTune:
    lda #$00                                               // EF01
    sta ZP_MUSIC0_STATE                                    // EF03
    sta ZP_MUSIC1_STATE                                    // EF05
    sta ZP_MUSIC2_STATE                                    // EF07
    sta ZP_MUSIC_EFFECT_MASK                               // EF09
    lda.abs TuneHeaderLo, x                                // EF0B
    sta ZP_MUSIC_SCRATCH_LO                                // EF0E
    lda.abs TuneHeaderHi, x                                // EF10
    sta ZP_MUSIC_SCRATCH_HI                                // EF13
    ldy #$05                                               // EF15

L_EF17:
    lda (ZP_MUSIC_SCRATCH_LO), y                           // EF17
    sta.abs ZP_MUSIC0_PTR_LO, y                            // EF19
    dey                                                    // EF1C
    bpl L_EF17                                             // EF1D
    ldy #$01                                               // EF1F
    ldx #$04                                               // EF21
    lda #$80                                               // EF23

L_EF25:
    sta ZP_MUSIC0_STATE, x                                 // EF25
    sty ZP_MUSIC0_DURATION, x                              // EF27
    dex                                                    // EF29
    dex                                                    // EF2A
    bpl L_EF25                                             // EF2B

L_EF2D:
    rts                                                    // EF2D

// Choose feedback pitch/control $3C, then common short-tone path.
PlayFeedbackTone3C:
    ldy #$3c                                               // EF2E
    bne PlayFeedbackToneCommon                             // EF30

// Choose feedback pitch/control $3A.
PlayFeedbackTone3A:
    ldy #$3a                                               // EF32
    bne PlayFeedbackToneCommon                             // EF34
    ldy #$38                                               // EF36
    bne PlayFeedbackToneCommon                             // EF38

// Choose feedback pitch/control $36.
PlayFeedbackTone36:
    ldy #$36                                               // EF3A

// A=$0A duration; Y supplied pitch/control; share error-tone launch path.
PlayFeedbackToneCommon:
    lda #$0a                                               // EF3C
    bne L_EF44                                             // EF3E

// Start short foreground feedback/error tone unless music activity blocks it.
PlayErrorTone:
    ldy #$01                                               // EF40
    lda #$6f                                               // EF42

L_EF44:
    bit ZP_MUSIC0_STATE                                    // EF44
    bmi L_EF2D                                             // EF46
    sta ZP_MUSIC0_DURATION                                 // EF48
    lda #$40                                               // EF4A
    ora ZP_MUSIC0_STATE                                    // EF4C
    sta ZP_MUSIC0_STATE                                    // EF4E
    ldx #$00                                               // EF50
    jmp L_F222                                             // EF52

// Clear $0400-$04FF and reset tune editor offset/octave state.
ClearUserTune:
    lda #$00                                               // EF55
    tax                                                    // EF57

L_EF58:
    sta.abs USER_TUNE, x                                   // EF58
    inx                                                    // EF5B
    bne L_EF58                                             // EF5C
    stx ZP_NOTE_OFFSET                                     // EF5E
    stx ZP_NOTE_BASE                                       // EF60
    rts                                                    // EF62

// Wait for voice-0 active/state byte to become zero; depends on IRQ music service.
WaitForTune:
    lda ZP_MUSIC0_STATE                                    // EF63
    bne WaitForTune                                        // EF65
    rts                                                    // EF67

// User-song editor/key loop.
EditUserTune:
    lda #$80                                               // EF68
    sta ZP_MUSIC_EDIT_FLAGS                                // EF6A

L_EF6C:
    jsr ServiceViaVector                                   // EF6C
    lda ZP_MUSIC_EDIT_FLAGS                                // EF6F
    lsr                                                    // EF71
    bcc L_EF6C                                             // EF72
    bcs L_EFB0                                             // EF74

// Select song/learn-song path and show Song prompt.
LearnUserTune:
    ldx #$00                                               // EF76
    jsr DisplayPreset                                      // EF78
    jsr WaitForTune                                        // EF7B
    bit ZP_FEATURE_FLAGS                                   // EF7E
    bvs L_EF89                                             // EF80
    jsr ClearUserTune                                      // EF82
    lda #$fe                                               // EF85
    sta ZP_NOTE_OFFSET                                     // EF87

L_EF89:
    lda #$ff                                               // EF89
    sta ZP_MUSIC_EDIT_FLAGS                                // EF8B
    sta ZP_NOTE_TEMP                                       // EF8D
    lda #$80                                               // EF8F
    sta ZP_REMOTE_MAILBOX                                  // EF91

L_EF93:
    jsr ServiceViaVector                                   // EF93
    lda ZP_NOTE_TEMP                                       // EF96
    cmp #$0e                                               // EF98
    bcs L_EF93                                             // EF9A

L_EF9C:
    jsr RefreshTuneDisplayIfChanged                        // EF9C
    ldx ZP_NOTE_OFFSET                                     // EF9F
    cpx #$fc                                               // EFA1
    bne L_EFA8                                             // EFA3
    jmp L_E2EC                                             // EFA5

L_EFA8:
    jsr ServiceViaVector                                   // EFA8
    lda ZP_MUSIC_EDIT_FLAGS                                // EFAB
    lsr                                                    // EFAD
    bcc L_EF9C                                             // EFAE

L_EFB0:
    lda ZP_NOTE_TEMP                                       // EFB0
    and #$20                                               // EFB2
    beq L_EFB0                                             // EFB4
    lda ZP_MUSIC_EDIT_FLAGS                                // EFB6
    and #$c0                                               // EFB8
    sta ZP_MUSIC_EDIT_FLAGS                                // EFBA
    lda ZP_NOTE_TEMP                                       // EFBC
    and #$1f                                               // EFBE
    cmp #$0d                                               // EFC0
    bne L_EFCE                                             // EFC2
    lda ZP_NOTE_BASE                                       // EFC4
    eor #$0c                                               // EFC6
    sta ZP_NOTE_BASE                                       // EFC8
    bit ZP_MUSIC_EDIT_FLAGS                                // EFCA
    bvs L_EF9C                                             // EFCC

L_EFCE:
    bit ZP_MUSIC_EDIT_FLAGS                                // EFCE
    bvc L_EF6C                                             // EFD0
    cmp #$17                                               // EFD2
    bne L_EF9C                                             // EFD4
    ldx #$00                                               // EFD6
    jsr SelectTune                                         // EFD8
    jsr WaitForTune                                        // EFDB
    beq L_EF9C                                             // EFDE

// Program-song path, note entry and clear/replay operations.
ProgramUserTune:
    ldx #$00                                               // EFE0
    jsr DisplayPreset                                      // EFE2
    jsr WaitForTune                                        // EFE5
    bit ZP_FEATURE_FLAGS                                   // EFE8
    bvs L_EFEF                                             // EFEA
    jsr ClearUserTune                                      // EFEC

L_EFEF:
    jsr DisplayTuneEditor                                  // EFEF
    jsr WaitForKeyPressAndRelease                          // EFF2

L_EFF5:
    cmp #$17                                               // EFF5
    beq L_F025                                             // EFF7
    cmp #$13                                               // EFF9
    beq L_F066                                             // EFFB
    cmp #$10                                               // EFFD
    bmi L_F006                                             // EFFF

L_F001:
    jsr PlayErrorTone                                      // F001
    bmi L_EFEF                                             // F004

L_F006:
    ldx ZP_NOTE_OFFSET                                     // F006
    cmp #$0c                                               // F008
    bmi L_F030                                             // F00A
    beq L_F02C                                             // F00C
    cmp #$0f                                               // F00E
    beq L_F077                                             // F010
    cmp #$0e                                               // F012
    beq L_F093                                             // F014
    lda ZP_NOTE_BASE                                       // F016
    eor #$0c                                               // F018
    sta ZP_NOTE_BASE                                       // F01A
    clc                                                    // F01C
    adc #$0d                                               // F01D
    tay                                                    // F01F
    jsr PlayFeedbackToneCommon                             // F020
    bmi L_EFEF                                             // F023

L_F025:
    ldx #$00                                               // F025
    jsr SelectTune                                         // F027
    bmi L_EFEF                                             // F02A

L_F02C:
    lda #$00                                               // F02C
    beq L_F035                                             // F02E

L_F030:
    clc                                                    // F030
    adc ZP_NOTE_BASE                                       // F031
    adc #$0d                                               // F033

L_F035:
    cpx #$fe                                               // F035
    bne L_F03C                                             // F037
    jmp L_E2EC                                             // F039

L_F03C:
    sta.abs USER_TUNE + 1, x                               // F03C
    tay                                                    // F03F
    beq L_F045                                             // F040
    jsr PlayFeedbackToneCommon                             // F042

L_F045:
    lda #$01                                               // F045
    ldx ZP_NOTE_OFFSET                                     // F047
    sta.abs USER_TUNE, x                                   // F049
    jsr DisplayTuneEditor                                  // F04C
    jsr WaitForKeyPressAndRelease                          // F04F
    beq L_F001                                             // F052
    cmp #$09                                               // F054

L_F056:
    bpl L_F001                                             // F056
    tax                                                    // F058
    lda.abs MusicDurationTable - 1, x                      // F059
    ldx ZP_NOTE_OFFSET                                     // F05C
    sta.abs USER_TUNE, x                                   // F05E
    jsr PlayFeedbackTone3A                                 // F061
    bmi L_EFEF                                             // F064

L_F066:
    ldx ZP_NOTE_OFFSET                                     // F066
    beq L_EFEF                                             // F068
    dex                                                    // F06A
    dex                                                    // F06B
    lda.abs USER_TUNE, x                                   // F06C
    sta ZP_MUSIC0_DURATION                                 // F06F
    lda.abs USER_TUNE + 1, x                               // F071
    jmp L_F085                                             // F074

L_F077:
    ldx ZP_NOTE_OFFSET                                     // F077
    lda.abs USER_TUNE, x                                   // F079
    beq L_F090                                             // F07C; missing BEQ restored from binary
    sta ZP_MUSIC0_DURATION                                 // F07E
    lda.abs USER_TUNE + 1, x                               // F080
    inx                                                    // F083
    inx                                                    // F084

L_F085:
    stx ZP_NOTE_OFFSET                                     // F085
    ldx #$80                                               // F087
    stx ZP_MUSIC0_STATE                                    // F089
    ldx #$00                                               // F08B
    jsr ProgramTone                                        // F08D

L_F090:
    jmp L_EFEF                                             // F090

L_F093:
    lda #$00                                               // F093
    ldx ZP_NOTE_OFFSET                                     // F095
    beq L_F056                                             // F097
    dex                                                    // F099
    sta.abs USER_TUNE, x                                   // F09A
    dex                                                    // F09D
    sta.abs USER_TUNE, x                                   // F09E
    stx ZP_NOTE_OFFSET                                     // F0A1
    jsr PlayFeedbackTone3C                                 // F0A3
    jsr DisplayTuneEditor                                  // F0A6
    jsr WaitForKeyPressAndRelease                          // F0A9
    cmp #$10                                               // F0AC
    beq L_F0B3                                             // F0AE
    jmp L_EFF5                                             // F0B0

L_F0B3:
    jsr ClearUserTune                                      // F0B3
    beq L_F090                                             // F0B6

// Preserve A; compare note-base and duration selection, refresh tune display on change.
RefreshTuneDisplayIfChanged:
    pha                                                    // F0B8
    ldx ZP_NOTE_OFFSET                                     // F0B9
    lda ZP_NOTE_BASE                                       // F0BB
    cmp ZP_OPERAND                                         // F0BD
    bne L_F0CB                                             // F0BF
    lda.abs USER_TUNE, x                                   // F0C1
    jsr FindDurationIndex                                  // F0C4
    cpx ZP_OPERATION_INDEX                                 // F0C7
    beq L_F0CE                                             // F0C9

L_F0CB:
    jsr DisplayTuneEditor                                  // F0CB

L_F0CE:
    pla                                                    // F0CE
    rts                                                    // F0CF

// Preserve A/X/Y; display note offset, pitch and duration, with octave point.
DisplayTuneEditor:
    pha                                                    // F0D0
    txa                                                    // F0D1
    pha                                                    // F0D2
    tya                                                    // F0D3
    pha                                                    // F0D4
    lda ZP_NOTE_OFFSET                                     // F0D5
    lsr                                                    // F0D7
    jsr ByteToBCD                                          // F0D8
    jsr BeginHeadDisplayFrame                              // F0DB
    lda ZP_DISPLAY_EDIT_LO                                 // F0DE
    pha                                                    // F0E0
    lsr                                                    // F0E1
    lsr                                                    // F0E2
    lsr                                                    // F0E3
    lsr                                                    // F0E4
    tax                                                    // F0E5
    clc                                                    // F0E6
    lda ZP_NOTE_BASE                                       // F0E7
    sta ZP_OPERAND                                         // F0E9
    beq L_F0EF                                             // F0EB
    lda #$01                                               // F0ED

L_F0EF:
    ora.abs DigitSegmentGlyphs, x                          // F0EF
    jsr SendHeadByte                                       // F0F2
    ldx ZP_NOTE_OFFSET                                     // F0F5
    lda.abs USER_TUNE, x                                   // F0F7
    ora.abs USER_TUNE + 1, x                               // F0FA
    bne L_F103                                             // F0FD
    ldy #$10                                               // F0FF
    bne L_F113                                             // F101

L_F103:
    ldy #$0a                                               // F103
    lda.abs USER_TUNE + 1, x                               // F105
    beq L_F113                                             // F108

L_F10A:
    sec                                                    // F10A
    sbc #$0c                                               // F10B
    bpl L_F10A                                             // F10D
    tax                                                    // F10F
    ldy.abs MusicNoteGlyphs - $f4, x                       // F110

L_F113:
    pla                                                    // F113
    and #$0f                                               // F114
    tax                                                    // F116
    tya                                                    // F117
    and #$01                                               // F118
    ora.abs DigitSegmentGlyphs, x                          // F11A
    jsr SendHeadByte                                       // F11D
    tya                                                    // F120
    jsr SendHeadByte                                       // F121
    ldx ZP_NOTE_OFFSET                                     // F124
    lda.abs USER_TUNE, x                                   // F126
    jsr FindDurationIndex                                  // F129
    stx ZP_OPERATION_INDEX                                 // F12C
    lda.abs DigitSegmentGlyphs + 1, x                      // F12E
    cmp #$e6                                               // F131
    bne L_F137                                             // F133
    lda #$10                                               // F135

L_F137:
    jsr SendHeadByte                                       // F137
    lda #$e2                                               // F13A
    jsr SendHeadByte                                       // F13C
    pla                                                    // F13F
    tay                                                    // F140
    pla                                                    // F141
    tax                                                    // F142
    pla                                                    // F143
    rts                                                    // F144

MusicNoteGlyphs:
    .byte $3e // F145; Music pitch glyph 0; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $9c // F146; Music pitch glyph 1; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $9d // F147; Music pitch glyph 2; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $7a // F148; Music pitch glyph 3; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $7b // F149; Music pitch glyph 4; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $9e // F14A; Music pitch glyph 5; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $8e // F14B; Music pitch glyph 6; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $8f // F14C; Music pitch glyph 7; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $f6 // F14D; Music pitch glyph 8; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $f7 // F14E; Music pitch glyph 9; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $ee // F14F; Music pitch glyph 10; lookup uses biased base MusicNoteGlyphs-$f4.
    .byte $ef // F150; Music pitch glyph 11; lookup uses biased base MusicNoteGlyphs-$f4.

// Find duration encoding by comparing the biased table; table index zero overlaps the RTS byte.
FindDurationIndex:
    ldx #$08                                               // F151

L_F153:
    cmp.abs MusicDurationTable - 1, x                      // F153
    bcc L_F15B                                             // F156
    dex                                                    // F158
    bne L_F153                                             // F159

L_F15B:
    rts                                                    // F15B; RTS opcode $60 is also duration-table index zero

MusicDurationTable:
    .byte $e0, $a8, $70, $54, $38, $2a, $1c, $0e // F15C; Duration entries 1..8. Index zero deliberately reads the RTS byte at $F15B.

// Update programmable note data and editor state.
SetTuneNote:
    cpx #$fc                                               // F164
    beq L_F173                                             // F166
    inx                                                    // F168
    inx                                                    // F169
    sta.abs USER_TUNE + 1, x                               // F16A
    inc.abs USER_TUNE, x                                   // F16D
    stx ZP_NOTE_OFFSET                                     // F170
    rts                                                    // F172

L_F173:
    pla                                                    // F173
    pla                                                    // F174
    ldx #$00                                               // F175
    beq L_F1F5                                             // F177

L_F179:
    bit ZP_MUSIC_EDIT_FLAGS                                // F179
    bvc L_F195                                             // F17B
    lda ZP_NOTE_TEMP                                       // F17D
    and #$1f                                               // F17F
    cmp #$0e                                               // F181
    bcs L_F195                                             // F183
    ldx ZP_NOTE_OFFSET                                     // F185
    inc.abs USER_TUNE, x                                   // F187
    bne L_F195                                             // F18A
    dec.abs USER_TUNE, x                                   // F18C
    lda.abs USER_TUNE + 1, x                               // F18F
    jsr SetTuneNote                                        // F192

L_F195:
    jmp IRQRestore                                         // F195

L_F198:
    txa                                                    // F198
    bne L_F195                                             // F199
    bit ZP_MUSIC_EDIT_FLAGS                                // F19B
    bpl L_F195                                             // F19D
    ldy ZP_REMOTE_MAILBOX                                  // F19F
    bmi L_F179                                             // F1A1
    sty ZP_NOTE_TEMP                                       // F1A3
    lda #$80                                               // F1A5
    sta ZP_REMOTE_MAILBOX                                  // F1A7
    cpy #$2c                                               // F1A9
    bcs L_F195                                             // F1AB
    asl                                                    // F1AD
    cpy #$20                                               // F1AE
    bcs L_F1C5                                             // F1B0
    cpy #$0c                                               // F1B2
    bcc L_F1BF                                             // F1B4
    beq L_F1C5                                             // F1B6
    lsr ZP_MUSIC_EDIT_FLAGS                                // F1B8
    sec                                                    // F1BA
    rol ZP_MUSIC_EDIT_FLAGS                                // F1BB
    bne L_F1F5                                             // F1BD

L_F1BF:
    tya                                                    // F1BF
    clc                                                    // F1C0
    adc ZP_NOTE_BASE                                       // F1C1
    adc #$0d                                               // F1C3

L_F1C5:
    tay                                                    // F1C5
    lda ZP_MUSIC_EDIT_FLAGS                                // F1C6
    and #$c0                                               // F1C8
    sta ZP_MUSIC_EDIT_FLAGS                                // F1CA
    asl                                                    // F1CC
    bpl L_F1D5                                             // F1CD
    ldx ZP_NOTE_OFFSET                                     // F1CF
    tya                                                    // F1D1
    jsr SetTuneNote                                        // F1D2

L_F1D5:
    tya                                                    // F1D5
    jmp L_F207                                             // F1D6

// IRQ task for slots 0,1,2; stream duration/note fetch or effect RTS dispatch.
MusicIRQ:
    lda ZP_IRQ_SLOT                                        // F1D9
    tay                                                    // F1DB
    asl                                                    // F1DC
    tax                                                    // F1DD
    lda.abs MusicEffectSetMasks, y                         // F1DE
    and ZP_MUSIC_EFFECT_MASK                               // F1E1
    bne L_F20F                                             // F1E3
    lda ZP_MUSIC0_STATE, x                                 // F1E5
    beq L_F198                                             // F1E7
    dec ZP_MUSIC0_DURATION, x                              // F1E9
    bne L_F20C                                             // F1EB
    bit ZP_MUSIC0_STATE                                    // F1ED
    bvs L_F1F5                                             // F1EF
    lda (ZP_MUSIC0_PTR_LO, x)                              // F1F1
    bne L_F1FB                                             // F1F3

L_F1F5:
    lda #$00                                               // F1F5
    sta ZP_MUSIC0_STATE, x                                 // F1F7
    beq L_F207                                             // F1F9

L_F1FB:
    sta ZP_MUSIC0_DURATION, x                              // F1FB
    inc ZP_MUSIC0_PTR_LO, x                                // F1FD
    lda (ZP_MUSIC0_PTR_LO, x)                              // F1FF
    inc ZP_MUSIC0_PTR_LO, x                                // F201
    bne L_F207                                             // F203
    inc ZP_MUSIC0_PTR_HI, x                                // F205

L_F207:
    ldx ZP_IRQ_SLOT                                        // F207
    jsr ProgramTone                                        // F209

L_F20C:
    jmp IRQRestore                                         // F20C

L_F20F:
    dec ZP_MUSIC0_DURATION, x                              // F20F
    bne L_F20C                                             // F211
    lda.abs ZP_EFFECT0_VECTOR_HI, y                        // F213
    pha                                                    // F216
    lda.abs ZP_EFFECT0_VECTOR_LO, y                        // F217
    pha                                                    // F21A
    rts                                                    // F21B

// First writes raw note to lamps; compute period and emit four encoded writes to $1C00.
ProgramTone:
    tay                                                    // F21C
    sta.abs IO_LAMPS_ALARM_BATTERY                         // F21D
    beq MuteSelectedMusicVoice                             // F220

L_F222:
    dey                                                    // F222
    tya                                                    // F223
    ldy #$00                                               // F224

L_F226:
    sec                                                    // F226
    sbc #$0c                                               // F227
    bmi L_F22E                                             // F229
    iny                                                    // F22B
    bpl L_F226                                             // F22C

L_F22E:
    sty ZP_MUSIC_SCRATCH_HI                                // F22E
    tay                                                    // F230
    lda.abs TonePeriodLowTable - $f4, y                    // F231
    sta ZP_MUSIC_SCRATCH_LO                                // F234
    lda.abs TonePeriodHighTable - $f4, y                   // F236
    ldy ZP_MUSIC_SCRATCH_HI                                // F239

L_F23B:
    lsr ZP_MUSIC_SCRATCH_LO                                // F23B
    ror                                                    // F23D
    dey                                                    // F23E
    bpl L_F23B                                             // F23F
    lsr                                                    // F241
    lsr                                                    // F242
    lsr                                                    // F243
    lsr                                                    // F244
    ora.abs ToneChannelControls, x                         // F245
    and #$ef                                               // F248
    sta.abs IO_TONE                                        // F24A
    jsr SoundWriteDelay                                    // F24D
    and #$7f                                               // F250
    sta.abs IO_TONE                                        // F252
    jsr SoundWriteDelay                                    // F255
    lda ZP_MUSIC_SCRATCH_LO                                // F258
    sta.abs IO_TONE                                        // F25A
    jsr SoundWriteDelay                                    // F25D
    lda.abs ToneChannelControls, x                         // F260

L_F263:
    sta.abs IO_TONE                                        // F263
    rts                                                    // F266

// Choose voice zero then disable effect/mute it.
StopMusicVoice0:
    ldx #$00                                               // F267
    beq DisableSelectedMusicEffect                         // F269

// Choose voice one then disable effect/mute it.
StopMusicVoice1:
    ldx #$01                                               // F26B
    bne DisableSelectedMusicEffect                         // F26D

// Choose voice two then disable effect/mute it.
StopMusicVoice2:
    ldx #$02                                               // F26F

// Clear selected voice effect mask then fall through to mute.
DisableSelectedMusicEffect:
    lda.abs MusicEffectClearMasks, x                       // F271
    and ZP_MUSIC_EFFECT_MASK                               // F274
    sta ZP_MUSIC_EFFECT_MASK                               // F276

// Write channel-control|$0F to tone port.
MuteSelectedMusicVoice:
    lda.abs ToneChannelControls, x                         // F278
    ora #$0f                                               // F27B
    bne L_F263                                             // F27D

// Tiny call/NOP timing delay between sound-port writes. Preserve exact instruction layout.
SoundWriteDelay:
    jsr SoundWriteDelayInner                               // F27F

// Two NOPs then RTS; cycle timing is part of stock sound programming.
SoundWriteDelayInner:
    nop                                                    // F282
    nop                                                    // F283
    rts                                                    // F284

// Consume a press then corresponding release while running service dispatch.
WaitForKeyPressAndRelease:
    jsr ServiceViaVector                                   // F285
    lda ZP_REMOTE_MAILBOX                                  // F288
    bmi WaitForKeyPressAndRelease                          // F28A
    ldy #$80                                               // F28C
    sty ZP_REMOTE_MAILBOX                                  // F28E
    and #$20                                               // F290
    bne WaitForKeyPressAndRelease                          // F292

L_F294:
    jsr ServiceViaVector                                   // F294
    lda ZP_REMOTE_MAILBOX                                  // F297
    bmi L_F294                                             // F299
    and #$20                                               // F29B
    beq L_F294                                             // F29D
    lda ZP_REMOTE_MAILBOX                                  // F29F
    ldy #$80                                               // F2A1
    sty ZP_REMOTE_MAILBOX                                  // F2A3
    and #$1f                                               // F2A5
    rts                                                    // F2A7

TonePeriodHighTable:
    .byte $60, $a0, $60, $60, $c0, $60, $60, $a0 // F2A8; Tone-period high bytes; negative-looking 8-bit index is added to a base biased by $f4.
    .byte $40, $00, $00, $40 // F2B0

TonePeriodLowTable:
    .byte $77, $70, $6a, $64, $5e, $59, $54, $4f // F2B4; Tone-period low bytes, same biased indexing.
    .byte $4b, $47, $43, $3f // F2BC

ToneChannelControls:
    .byte $90, $b0, $d0, $f0 // F2C0; Encoded channel control bytes: three tone voices plus fourth initialization entry.

// Music-effect entry; sets voice and handler/timing parameters.
ConfigureOscillatingEffect:
    ldy #$01                                               // F2C4

L_F2C6:
    ldx #<(MusicOscillatingEffectIRQ-1)                    // F2C6
    lda #>(MusicOscillatingEffectIRQ-1)                    // F2C8
    bne ConfigureMusicEffectCommon                         // F2CA

// Music-effect setup used by games and other tone paths.
ConfigureSweepEffect:
    ldy #$00                                               // F2CC
    ldx #<(MusicSweepEffectIRQ-1)                          // F2CE
    lda #>(MusicSweepEffectIRQ-1)                          // F2D0
    bne ConfigureMusicEffectCommon                         // F2D2

// Configure the random-effect handler with supplied parameter.
ConfigureRandomEffect:
    ldx #<(MusicRandomEffectIRQ-1)                         // F2D4
    lda #>(MusicRandomEffectIRQ-1)                         // F2D6
    sty ZP_EFFECT0_TIMING                                  // F2D8
    bne L_F2E4                                             // F2DA

// Configure effect decay/timing.
ConfigureDecayEffect:
    lda #$01                                               // F2DC
    sta ZP_EFFECT0_REPEAT                                  // F2DE
    ldx #<(MusicDecayEffectIRQ-1)                          // F2E0
    lda #>(MusicDecayEffectIRQ-1)                          // F2E2

L_F2E4:
    ldy #$00                                               // F2E4

// Install split RTS handler pointer and set effect-active mask.
ConfigureMusicEffectCommon:
    pha                                                    // F2E6
    lda.abs MusicEffectClearMasks, y                       // F2E7
    and ZP_MUSIC_EFFECT_MASK                               // F2EA
    sta ZP_MUSIC_EFFECT_MASK                               // F2EC
    stx ZP_EFFECT0_VECTOR_LO, y                            // F2EE
    pla                                                    // F2F0
    sta.abs ZP_EFFECT0_VECTOR_HI, y                        // F2F1
    tya                                                    // F2F4
    asl                                                    // F2F5
    tax                                                    // F2F6
    lda #$01                                               // F2F7
    sta ZP_MUSIC0_DURATION, x                              // F2F9
    lda ZP_EFFECT0_REPEAT, x                               // F2FB
    sta ZP_EFFECT0_TIMING_AUX, x                           // F2FD
    lda.abs MusicEffectSetMasks, y                         // F2FF
    ora ZP_MUSIC_EFFECT_MASK                               // F302
    sta ZP_MUSIC_EFFECT_MASK                               // F304
    rts                                                    // F306

// Music-effect callback entered through RTS table; returns through IRQ restore paths.
MusicDecayEffectIRQ:
    dec ZP_EFFECT0_TIMING_AUX                              // F307
    bpl L_F313                                             // F309
    lda #$02                                               // F30B
    sta ZP_EFFECT0_TIMING_AUX                              // F30D
    dec ZP_EFFECT0_VALUE                                   // F30F
    bne L_F315                                             // F311

L_F313:
    inc ZP_EFFECT0_VALUE                                   // F313

L_F315:
    sec                                                    // F315
    lda ZP_EFFECT0_VALUE                                   // F316
    sbc #$38                                               // F318
    beq L_F329                                             // F31A
    sec                                                    // F31C
    lda #$50                                               // F31D
    sbc ZP_EFFECT0_VALUE                                   // F31F
    lsr                                                    // F321
    sta ZP_MUSIC0_DURATION                                 // F322
    bne L_F343                                             // F324

// Effect callback and shared effect-step update.
MusicSweepEffectIRQ:
    jsr AdvanceMusicEffectStep                             // F326

L_F329:
    ldx ZP_IRQ_SLOT                                        // F329
    jsr DisableSelectedMusicEffect                         // F32B
    jmp IRQRestore                                         // F32E

// Update effect counters and value/increment; call context can alter return stack.
AdvanceMusicEffectStep:
    lda ZP_EFFECT0_TIMING, x                               // F331
    sta ZP_MUSIC0_DURATION, x                              // F333
    clc                                                    // F335
    lda ZP_EFFECT0_VALUE, x                                // F336
    adc ZP_EFFECT0_VALUE_AUX, x                            // F338
    sta ZP_EFFECT0_VALUE, x                                // F33A
    dec ZP_EFFECT0_TIMING_AUX, x                           // F33C
    bne L_F341                                             // F33E
    rts                                                    // F340

L_F341:
    pla                                                    // F341
    pla                                                    // F342

L_F343:
    lda ZP_EFFECT0_VALUE, x                                // F343

L_F345:
    jmp L_F207                                             // F345

// Calls NextRandom. This dependency prevents deleting all game-adjacent code wholesale.
MusicRandomEffectIRQ:
    lda ZP_EFFECT0_TIMING                                  // F348
    sta ZP_MUSIC0_DURATION                                 // F34A
    jsr NextRandom                                         // F34C
    lda ZP_RANDOM_LO                                       // F34F
    and #$3f                                               // F351
    tay                                                    // F353
    iny                                                    // F354
    tya                                                    // F355
    bne L_F345                                             // F356

// Reverse increment at effect endpoints.
MusicOscillatingEffectIRQ:
    jsr AdvanceMusicEffectStep                             // F358

L_F35B:
    lda ZP_EFFECT0_REPEAT, x                               // F35B
    sta ZP_EFFECT0_TIMING_AUX, x                           // F35D
    lda ZP_EFFECT0_VALUE_AUX, x                            // F35F
    eor #$ff                                               // F361
    sta ZP_EFFECT0_VALUE_AUX, x                            // F363
    inc ZP_EFFECT0_VALUE_AUX, x                            // F365
    bne L_F343                                             // F367

// Effect repetition/counter path.
MusicRepeatedSweepIRQ:
    jsr AdvanceMusicEffectStep                             // F369
    dec ZP_EFFECT0_REPEAT_AUX, x                           // F36C
    bne L_F35B                                             // F36E
    beq L_F329                                             // F370

MusicEffectClearMasks:
    .byte $fe, $fd, $fb // F372; Per-voice AND masks for clearing effect-active bits.

MusicEffectSetMasks:
    .byte $01, $02, $04 // F375; Per-voice OR masks for setting effect-active bits.
.assert "30_music end", *, $0f378
