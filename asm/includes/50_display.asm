// Program/operand formatting, four-glyph output, and packed BCD conversion
// Original CPU range $f64e-$f75d.
.assert "50_display start", *, $f64e

// Derive step number from biased cursor, convert to BCD, and send numeric display.
DisplayProgramPosition:
    lda ZP_PROGRAM_CURSOR_LO                               // F64E
    sec                                                    // F650
    sbc #$80                                               // F651
    sta ZP_OPERAND                                         // F653
    lda ZP_PROGRAM_CURSOR_HI                               // F655
    sbc #$01                                               // F657
    lsr                                                    // F659
    ror ZP_OPERAND                                         // F65A
    jsr OperandToBCD                                       // F65C
    jsr BeginHeadDisplayFrame                              // F65F
    ldx #$00                                               // F662
    txa                                                    // F664
    jmp L_F6EB                                             // F665

// Prompt-format entry with leading/placeholder behavior.
DisplayOperandPrompt:
    ldx #$f0                                               // F668
    bne L_F67C                                             // F66A

// Format $11/$13; special FE/FF selects beginning/end presets, 0B selects init.
DisplayCommandOperand:
    jsr OperandToBCD                                       // F66C
    ldy ZP_OPCODE                                          // F66F
    ldx #$0e                                               // F671
    iny                                                    // F673
    beq DisplayPreset                                      // F674
    inx                                                    // F676
    iny                                                    // F677
    beq DisplayPreset                                      // F678
    ldx #$ff                                               // F67A

L_F67C:
    lda ZP_OPCODE                                          // F67C
    cmp #$0b                                               // F67E
    bne DisplayMixedCommand                                // F680
    ldx #$10                                               // F682

// X=0..31; send four glyphs from split preset tables and commit.
DisplayPreset:
    jsr BeginHeadDisplayFrame                              // F684
    lda.abs DisplayPresetGlyph0, x                         // F687
    jsr SendHeadByte                                       // F68A
    lda.abs DisplayPresetGlyph1, x                         // F68D
    jsr SendHeadByte                                       // F690
    lda.abs DisplayPresetGlyph2, x                         // F693
    jsr SendHeadByte                                       // F696
    lda.abs DisplayPresetGlyph3, x                         // F699

L_F69C:
    jsr SendHeadByte                                       // F69C
    lda #$e2                                               // F69F
    jmp SendHeadByte                                       // F6A1

// Command-specific label glyphs combined with decimal operand digits.
DisplayMixedCommand:
    lda ZP_OPCODE                                          // F6A4
    bpl L_F6AD                                             // F6A6
    and #$07                                               // F6A8
    clc                                                    // F6AA
    adc #$0c                                               // F6AB

L_F6AD:
    sta ZP_OPERATION_INDEX                                 // F6AD
    jsr BeginHeadDisplayFrame                              // F6AF
    ldy ZP_OPERATION_INDEX                                 // F6B2
    lda.abs CommandGlyph0, y                               // F6B4
    jsr SendHeadByte                                       // F6B7
    lda.abs CommandFormatSelectors, y                      // F6BA
    beq L_F6EE                                             // F6BD
    lda.abs CommandGlyph1, y                               // F6BF
    jsr SendHeadByte                                       // F6C2
    lda.abs CommandFormatSelectors, y                      // F6C5
    bmi L_F703                                             // F6C8
    lda.abs CommandGlyph2, y                               // F6CA
    jsr SendHeadByte                                       // F6CD
    beq L_F71A                                             // F6D0

// Numeric formatting with leading blanks.
DisplayNumberBlanked:
    ldx #$ff                                               // F6D2
    bmi DisplayNumberCommon                                // F6D4

// Display packed BCD $24/$25 with leading zeroes.
DisplayNumberZeroFilled:
    ldx #$00                                               // F6D6

// Shared four-digit formatter; X controls leading-zero suppression.
DisplayNumberCommon:
    jsr BeginHeadDisplayFrame                              // F6D8
    lda ZP_DISPLAY_EDIT_HI                                 // F6DB
    lsr                                                    // F6DD
    lsr                                                    // F6DE
    lsr                                                    // F6DF
    lsr                                                    // F6E0
    bne L_F6E7                                             // F6E1
    cpx #$ff                                               // F6E3
    beq L_F6EB                                             // F6E5

L_F6E7:
    tax                                                    // F6E7
    lda.abs DigitSegmentGlyphs, x                          // F6E8

L_F6EB:
    jsr SendHeadByte                                       // F6EB

L_F6EE:
    cpx #$f0                                               // F6EE
    beq L_F729                                             // F6F0
    lda ZP_DISPLAY_EDIT_HI                                 // F6F2
    and #$0f                                               // F6F4
    bne L_F6FC                                             // F6F6
    cpx #$ff                                               // F6F8
    beq L_F700                                             // F6FA

L_F6FC:
    tax                                                    // F6FC
    lda.abs DigitSegmentGlyphs, x                          // F6FD

L_F700:
    jsr SendHeadByte                                       // F700

L_F703:
    cpx #$f0                                               // F703
    beq L_F72E                                             // F705
    lda ZP_DISPLAY_EDIT_LO                                 // F707
    lsr                                                    // F709
    lsr                                                    // F70A
    lsr                                                    // F70B
    lsr                                                    // F70C
    bne L_F713                                             // F70D
    cpx #$ff                                               // F70F
    beq L_F717                                             // F711

L_F713:
    tax                                                    // F713
    lda.abs DigitSegmentGlyphs, x                          // F714

L_F717:
    jsr SendHeadByte                                       // F717

L_F71A:
    cpx #$f0                                               // F71A
    beq L_F733                                             // F71C
    lda ZP_DISPLAY_EDIT_LO                                 // F71E
    and #$0f                                               // F720
    tax                                                    // F722
    lda.abs DigitSegmentGlyphs, x                          // F723

L_F726:
    jmp L_F69C                                             // F726

L_F729:
    lda #$10                                               // F729
    jsr SendHeadByte                                       // F72B

L_F72E:
    lda #$10                                               // F72E
    jsr SendHeadByte                                       // F730

L_F733:
    lda #$10                                               // F733
    bne L_F726                                             // F735

// Load current operand then convert to packed BCD.
OperandToBCD:
    lda ZP_OPERAND                                         // F737

// A=unsigned byte; result in $24/$25. Temporarily enters decimal mode and clears it before RTS.
ByteToBCD:
    sta ZP_DISPLAY_EDIT_LO                                 // F739
    asl                                                    // F73B
    lda #$00                                               // F73C
    rol                                                    // F73E
    sta ZP_DISPLAY_EDIT_HI                                 // F73F
    sed                                                    // F741
    ldy #$07                                               // F742

L_F744:
    asl ZP_DISPLAY_EDIT_LO                                 // F744
    bcc L_F74F                                             // F746
    adc.abs BCDAdjustmentTable, y                          // F748
    bcc L_F74F                                             // F74B
    inc ZP_DISPLAY_EDIT_HI                                 // F74D

L_F74F:
    dey                                                    // F74F
    bpl L_F744                                             // F750
    sta ZP_DISPLAY_EDIT_LO                                 // F752
    cld                                                    // F754
    rts                                                    // F755

BCDAdjustmentTable:
    .byte $00, $01, $03, $07, $15, $31, $63, $26 // F756; Packed-BCD conversion adjustment bytes.
.assert "50_display end", *, $0f75e
