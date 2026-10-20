// Copyright, reset, warm/cold initialization, and cartridge dispatch
// Original CPU range $e000-$e0ca.
.assert "00_boot start", *, $e000

CopyrightText:
    .text "(c) 1984 CBS Toys" // E000; 17 bytes; also copied into the warm-start marker.
CopyrightTextEnd:

// Hardware NMI trampoline through writable RAM vector $0076/$0077.
NMIEntry:
    jmp (ZP_NMI_VECTOR)                                    // E011

// Preserve A, write zero to $1E00, and RTI. Hardware side effect remains unresolved.
NMIDefault:
    pha                                                    // E014
    lda #$00                                               // E015
    sta.abs IO_SYSTEM_CONTROL                              // E017
    pla                                                    // E01A
    rti                                                    // E01B

InitialRAMTable:
    .byte $82, $00, $00, $80 // E01C; Headlamp divider, inactivity bytes, and empty mailbox.
    .word NMIDefault // E020
    .word IRQDefault // E022
    .word MainModeEntry // E024
    .byte <(MusicIRQ-1), <(MusicIRQ-1), <(MusicIRQ-1), <(IRQRestore-1), <(TimerIRQ-1), <(HeadlampIRQ-1), <(IRQRestore-1), <(SpeechIRQ-1) // E026; IRQ task low bytes: RTS requires target minus one.
    .byte >(MusicIRQ-1), >(MusicIRQ-1), >(MusicIRQ-1), >(IRQRestore-1), >(TimerIRQ-1), >(HeadlampIRQ-1), >(IRQRestore-1), >(SpeechIRQ-1) // E02E; Corresponding IRQ task high bytes.
    .word ServiceDefault // E036
    .word $1000 // E038
    .word ReadOperandDefault // E03A
    .word SpeakVocabularyDefault // E03C
    .word GamesEntry // E03E
    .byte $ff // E040; Initial battery countdown/state.
InitialRAMTableEnd:

// SEI/CLD, fixed page-1 stack, marker test, cold/warm initialization, then cartridge search.
ResetEntry:
    sei                                                    // E041
    ldx #$00                                               // E042
    stx.abs IO_SYSTEM_CONTROL                              // E044
    stx.abs IO_COP_CONTROL_STATUS                          // E047
    cld                                                    // E04A
    dex                                                    // E04B
    txs                                                    // E04C
    ldy #$11                                               // E04D

// Compare all 17 copyright bytes against RAM $0100-$0110.
CheckWarmStartMarker:
    dey                                                    // E04F
    bmi InitializeCommonState                              // E050
    lda.abs CopyrightText, y                               // E052
    cmp.abs RAM_WARM_MARKER, y                             // E055
    beq CheckWarmStartMarker                               // E058

// Clear zero page; fill user phrase storage with $FF. Do not clear the full command area.
ColdStartInitialize:
    ldy #$00                                               // E05A
    txa                                                    // E05C
    inx                                                    // E05D

L_E05E:
    sty ZP_UI_FLAGS, x                                     // E05E
    sta.abs USER_PHRASES, x                                // E060
    dex                                                    // E063
    bne L_E05E                                             // E064
    jsr ClearUserTune                                      // E066
    jsr ResetProgramCursor                                 // E069
    jsr MarkProgramEnd                                     // E06C

// Runs on warm and cold reset; reinstall marker, vectors, remote ages, and music state.
InitializeCommonState:
    ldx #$10                                               // E06F

L_E071:
    lda.abs CopyrightText, x                               // E071
    sta.abs RAM_WARM_MARKER, x                             // E074
    dex                                                    // E077
    bpl L_E071                                             // E078
    stx ZP_HELD0_AGE                                       // E07A
    stx ZP_HELD1_AGE                                       // E07C
    lda #$f8                                               // E07E
    sta.abs IO_COP_CONTROL_STATUS                          // E080
    ldx #$24                                               // E083

L_E085:
    lda.abs InitialRAMTable, x                             // E085
    sta ZP_HEADLAMP_DIVIDER, x                             // E088
    dex                                                    // E08A
    bpl L_E085                                             // E08B
    jsr InitializeMusicVoices                              // E08D

// Probe $2000,$3000,...,$B000 for four signature bytes; no $C000 probe.
ScanCartridge:
    ldy #$05                                               // E090
    clc                                                    // E092
    lda ZP_CARTRIDGE_PTR_HI                                // E093
    adc #$10                                               // E095
    sta ZP_CARTRIDGE_PTR_HI                                // E097
    cmp #$c0                                               // E099
    beq ContinueStockStartup                               // E09B

// Y=5..2: compare candidate bytes with CopyrightText-2,Y ($E003..$E000).
CompareCartridgeSignature:
    lda (ZP_CARTRIDGE_PTR), y                              // E09D
    cmp.abs CopyrightText - 2, y                           // E09F
    bne ScanCartridge                                      // E0A2
    dey                                                    // E0A4
    cpy #$01                                               // E0A5
    bne CompareCartridgeSignature                          // E0A7
    lda (ZP_CARTRIDGE_PTR), y                              // E0A9
    tax                                                    // E0AB
    dey                                                    // E0AC
    lda (ZP_CARTRIDGE_PTR), y                              // E0AD
    sta ZP_CARTRIDGE_PTR                                   // E0AF
    stx ZP_CARTRIDGE_PTR_HI                                // E0B1

// Jump through the header-supplied pointer; this is not a JSR and has no RTS return.
DispatchCartridge:
    jmp (ZP_CARTRIDGE_PTR)                                 // E0B3

// Stock continuation: head command, motor auxiliary status, CLI, spoken greeting.
ContinueStockStartup:
    lda #$e6                                               // E0B6
    jsr SendHeadByte                                       // E0B8
    lda #$30                                               // E0BB
    jsr ReadMotorReply                                     // E0BD
    sta ZP_MOTOR_AUX                                       // E0C0
    cli                                                    // E0C2
    ldx #$10                                               // E0C3
    jsr SpeakPromptUnlessDisabled                          // E0C5
    jsr PollMotorProgressAndService                        // E0C8
.assert "00_boot end", *, $0e0cb
