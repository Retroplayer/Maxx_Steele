// Padding, tune selection pointers, and three-voice stream data
// Original CPU range $fde6-$fff9.
.assert "72_tune_data start", *, $fde6

UnusedFFPadding:
    .fill 6, $ff // FDE6; Six unused-looking fill bytes, retained exactly; not yet a promised free-code area.

TuneHeaderLo:
    .byte <Tune0Pointers, <Tune1Pointers, <Tune2Pointers, <Tune3Pointers, <Tune4Pointers, <Tune5Pointers, <Tune6Pointers, <Tune7Pointers, <Tune8Pointers // FDEC; Tune-header low-byte table.

TuneHeaderHi:
    .byte >Tune0Pointers, >Tune1Pointers, >Tune2Pointers, >Tune3Pointers, >Tune4Pointers, >Tune5Pointers, >Tune6Pointers, >Tune7Pointers, >Tune8Pointers // FDF5; Tune-header high-byte table.

Tune0Pointers:
    .word USER_TUNE, SilentTuneStream, SilentTuneStream // FDFE; Tune 0: voice 0,1,2 stream pointers.

Tune1Pointers:
    .word Tune1Voice0, Tune1Voice1, SilentTuneStream // FE04; Tune 1: voice 0,1,2 stream pointers.

Tune1Voice0:
    .byte $16, $35 // FE0A; Encoded duration, note/control pair.
    .byte $16, $2c // FE0C; Encoded duration, note/control pair.
    .byte $16, $2e // FE0E; Encoded duration, note/control pair.
    .byte $16, $31 // FE10; Encoded duration, note/control pair.
    .byte $17, $38 // FE12; Encoded duration, note/control pair.
    .byte $00, $00 // FE14; Stream end: duration=0, note=0.

Tune1Voice1:
    .byte $16, $31 // FE16; Encoded duration, note/control pair.
    .byte $16, $29 // FE18; Encoded duration, note/control pair.
    .byte $16, $2c // FE1A; Encoded duration, note/control pair.
    .byte $16, $31 // FE1C; Encoded duration, note/control pair.
    .byte $17, $35 // FE1E; Encoded duration, note/control pair.
    .byte $00, $00 // FE20; Stream end: duration=0, note=0.

Tune2Pointers:
    .word Tune2Voice0, Tune2Voice1, Tune2Voice2 // FE22; Tune 2: voice 0,1,2 stream pointers.

Tune2Voice0:
    .byte $84, $38 // FE28; Encoded duration, note/control pair.
    .byte $84, $35 // FE2A; Encoded duration, note/control pair.
    .byte $84, $33 // FE2C; Encoded duration, note/control pair.
    .byte $84, $31 // FE2E; Encoded duration, note/control pair.
    .byte $58, $33 // FE30; Encoded duration, note/control pair.
    .byte $2c, $31 // FE32; Encoded duration, note/control pair.
    .byte $58, $2e // FE34; Encoded duration, note/control pair.
    .byte $2c, $31 // FE36; Encoded duration, note/control pair.
    .byte $84, $2e // FE38; Encoded duration, note/control pair.
    .byte $84, $2c // FE3A; Encoded duration, note/control pair.
    .byte $00, $00 // FE3C; Stream end: duration=0, note=0.

Tune2Voice1:
    .byte $84, $35 // FE3E; Encoded duration, note/control pair.
    .byte $84, $31 // FE40; Encoded duration, note/control pair.
    .byte $b0, $30 // FE42; Encoded duration, note/control pair.
    .byte $2c, $2c // FE44; Encoded duration, note/control pair.
    .byte $2c, $29 // FE46; Encoded duration, note/control pair.
    .byte $16, $22 // FE48; Encoded duration, note/control pair.
    .byte $16, $24 // FE4A; Encoded duration, note/control pair.
    .byte $16, $25 // FE4C; Encoded duration, note/control pair.
    .byte $16, $27 // FE4E; Encoded duration, note/control pair.
    .byte $16, $29 // FE50; Encoded duration, note/control pair.
    .byte $6e, $2a // FE52; Encoded duration, note/control pair.
    .byte $2c, $2e // FE54; Encoded duration, note/control pair.
    .byte $2c, $2a // FE56; Encoded duration, note/control pair.
    .byte $2c, $25 // FE58; Encoded duration, note/control pair.
    .byte $2c, $2a // FE5A; Encoded duration, note/control pair.
    .byte $84, $29 // FE5C; Encoded duration, note/control pair.
    .byte $00, $00 // FE5E; Stream end: duration=0, note=0.

Tune2Voice2:
    .byte $2c, $25 // FE60; Encoded duration, note/control pair.
    .byte $2c, $29 // FE62; Encoded duration, note/control pair.
    .byte $2c, $2c // FE64; Encoded duration, note/control pair.
    .byte $0b, $29 // FE66; Encoded duration, note/control pair.
    .byte $0b, $31 // FE68; Encoded duration, note/control pair.
    .byte $0b, $29 // FE6A; Encoded duration, note/control pair.
    .byte $0b, $31 // FE6C; Encoded duration, note/control pair.
    .byte $0b, $29 // FE6E; Encoded duration, note/control pair.
    .byte $0b, $31 // FE70; Encoded duration, note/control pair.
    .byte $0b, $29 // FE72; Encoded duration, note/control pair.
    .byte $0b, $31 // FE74; Encoded duration, note/control pair.
    .byte $0b, $29 // FE76; Encoded duration, note/control pair.
    .byte $0b, $31 // FE78; Encoded duration, note/control pair.
    .byte $0b, $29 // FE7A; Encoded duration, note/control pair.
    .byte $0b, $31 // FE7C; Encoded duration, note/control pair.
    .byte $2c, $24 // FE7E; Encoded duration, note/control pair.
    .byte $2c, $27 // FE80; Encoded duration, note/control pair.
    .byte $58, $2c // FE82; Encoded duration, note/control pair.
    .byte $2c, $27 // FE84; Encoded duration, note/control pair.
    .byte $2c, $25 // FE86; Encoded duration, note/control pair.
    .byte $16, $1e // FE88; Encoded duration, note/control pair.
    .byte $16, $20 // FE8A; Encoded duration, note/control pair.
    .byte $16, $22 // FE8C; Encoded duration, note/control pair.
    .byte $16, $24 // FE8E; Encoded duration, note/control pair.
    .byte $16, $25 // FE90; Encoded duration, note/control pair.
    .byte $16, $27 // FE92; Encoded duration, note/control pair.
    .byte $2c, $22 // FE94; Encoded duration, note/control pair.
    .byte $2c, $24 // FE96; Encoded duration, note/control pair.
    .byte $2c, $2a // FE98; Encoded duration, note/control pair.
    .byte $2c, $25 // FE9A; Encoded duration, note/control pair.
    .byte $2c, $22 // FE9C; Encoded duration, note/control pair.
    .byte $b0, $25 // FE9E; Encoded duration, note/control pair.
    .byte $00, $00 // FEA0; Stream end: duration=0, note=0.

Tune3Pointers:
    .word Tune3Voice0, Tune3Voice1, Tune3Voice2 // FEA2; Tune 3: voice 0,1,2 stream pointers.

Tune3Voice0:
    .byte $2c, $25 // FEA8; Encoded duration, note/control pair.
    .byte $2c, $2c // FEAA; Encoded duration, note/control pair.
    .byte $2c, $2a // FEAC; Encoded duration, note/control pair.
    .byte $2c, $31 // FEAE; Encoded duration, note/control pair.
    .byte $2c, $25 // FEB0; Encoded duration, note/control pair.
    .byte $2c, $2c // FEB2; Encoded duration, note/control pair.
    .byte $2c, $2a // FEB4; Encoded duration, note/control pair.
    .byte $2c, $31 // FEB6; Encoded duration, note/control pair.
    .byte $2c, $25 // FEB8; Encoded duration, note/control pair.
    .byte $2c, $2c // FEBA; Encoded duration, note/control pair.
    .byte $2c, $2a // FEBC; Encoded duration, note/control pair.
    .byte $2c, $31 // FEBE; Encoded duration, note/control pair.
    .byte $42, $00 // FEC0; Encoded duration, note/control pair.
    .byte $16, $2f // FEC2; Encoded duration, note/control pair.
    .byte $42, $00 // FEC4; Encoded duration, note/control pair.
    .byte $42, $2f // FEC6; Encoded duration, note/control pair.
    .byte $00, $00 // FEC8; Stream end: duration=0, note=0.

Tune3Voice1:
    .byte $b0, $00 // FECA; Encoded duration, note/control pair.
    .byte $2c, $31 // FECC; Encoded duration, note/control pair.
    .byte $2c, $38 // FECE; Encoded duration, note/control pair.
    .byte $2c, $36 // FED0; Encoded duration, note/control pair.
    .byte $2c, $3d // FED2; Encoded duration, note/control pair.
    .byte $2c, $31 // FED4; Encoded duration, note/control pair.
    .byte $2c, $38 // FED6; Encoded duration, note/control pair.
    .byte $2c, $36 // FED8; Encoded duration, note/control pair.
    .byte $2c, $3d // FEDA; Encoded duration, note/control pair.
    .byte $42, $00 // FEDC; Encoded duration, note/control pair.
    .byte $16, $38 // FEDE; Encoded duration, note/control pair.
    .byte $42, $00 // FEE0; Encoded duration, note/control pair.
    .byte $42, $38 // FEE2; Encoded duration, note/control pair.
    .byte $00, $00 // FEE4; Stream end: duration=0, note=0.

Tune3Voice2:
    .byte $ff, $00 // FEE6; Encoded duration, note/control pair.
    .byte $61, $00 // FEE8; Encoded duration, note/control pair.
    .byte $2c, $19 // FEEA; Encoded duration, note/control pair.
    .byte $2c, $20 // FEEC; Encoded duration, note/control pair.
    .byte $2c, $1e // FEEE; Encoded duration, note/control pair.
    .byte $2c, $25 // FEF0; Encoded duration, note/control pair.
    .byte $42, $00 // FEF2; Encoded duration, note/control pair.
    .byte $16, $25 // FEF4; Encoded duration, note/control pair.
    .byte $42, $00 // FEF6; Encoded duration, note/control pair.
    .byte $42, $25 // FEF8; Encoded duration, note/control pair.
    .byte $00, $00 // FEFA; Stream end: duration=0, note=0.

Tune4Pointers:
    .word Tune4Voice0, SilentTuneStream, SilentTuneStream // FEFC; Tune 4: voice 0,1,2 stream pointers.

Tune4Voice0:
    .byte $13, $25 // FF02; Encoded duration, note/control pair.
    .byte $14, $31 // FF04; Encoded duration, note/control pair.
    .byte $14, $2b // FF06; Encoded duration, note/control pair.
    .byte $14, $2c // FF08; Encoded duration, note/control pair.
    .byte $13, $2f // FF0A; Encoded duration, note/control pair.
    .byte $14, $31 // FF0C; Encoded duration, note/control pair.
    .byte $14, $26 // FF0E; Encoded duration, note/control pair.
    .byte $14, $31 // FF10; Encoded duration, note/control pair.

SilentTuneStream:
    .byte $00, $00 // FF12; Stream end: duration=0, note=0.

Tune5Pointers:
    .word Tune5Voice0, Tune5Voice1, Tune5Voice2 // FF14; Tune 5: voice 0,1,2 stream pointers.

Tune5Voice0:
    .byte $72, $25 // FF1A; Encoded duration, note/control pair.
    .byte $26, $27 // FF1C; Encoded duration, note/control pair.
    .byte $4c, $28 // FF1E; Encoded duration, note/control pair.
    .byte $4c, $25 // FF20; Encoded duration, note/control pair.
    .byte $18, $2f // FF22; Encoded duration, note/control pair.
    .byte $18, $2e // FF24; Encoded duration, note/control pair.
    .byte $18, $2d // FF26; Encoded duration, note/control pair.
    .byte $18, $2c // FF28; Encoded duration, note/control pair.
    .byte $18, $2b // FF2A; Encoded duration, note/control pair.
    .byte $18, $2a // FF2C; Encoded duration, note/control pair.
    .byte $98, $31 // FF2E; Encoded duration, note/control pair.
    .byte $00, $00 // FF30; Stream end: duration=0, note=0.

Tune5Voice1:
    .byte $ff, $00 // FF32; Encoded duration, note/control pair.
    .byte $79, $00 // FF34; Encoded duration, note/control pair.
    .byte $18, $3b // FF36; Encoded duration, note/control pair.
    .byte $18, $39 // FF38; Encoded duration, note/control pair.
    .byte $18, $38 // FF3A; Encoded duration, note/control pair.
    .byte $98, $3d // FF3C; Encoded duration, note/control pair.
    .byte $00, $00 // FF3E; Stream end: duration=0, note=0.

Tune5Voice2:
    .byte $ff, $00 // FF40; Encoded duration, note/control pair.
    .byte $31, $00 // FF42; Encoded duration, note/control pair.
    .byte $18, $23 // FF44; Encoded duration, note/control pair.
    .byte $18, $22 // FF46; Encoded duration, note/control pair.
    .byte $18, $21 // FF48; Encoded duration, note/control pair.
    .byte $18, $20 // FF4A; Encoded duration, note/control pair.
    .byte $18, $1f // FF4C; Encoded duration, note/control pair.
    .byte $18, $1e // FF4E; Encoded duration, note/control pair.
    .byte $98, $25 // FF50; Encoded duration, note/control pair.
    .byte $00, $00 // FF52; Stream end: duration=0, note=0.

Tune6Pointers:
    .word Tune6Voice0, SilentTuneStream, SilentTuneStream // FF54; Tune 6: voice 0,1,2 stream pointers.

Tune6Voice0:
    .byte $38, $14 // FF5A; Encoded duration, note/control pair.
    .byte $38, $19 // FF5C; Encoded duration, note/control pair.
    .byte $1c, $1d // FF5E; Encoded duration, note/control pair.
    .byte $1c, $19 // FF60; Encoded duration, note/control pair.
    .byte $38, $14 // FF62; Encoded duration, note/control pair.
    .byte $38, $1d // FF64; Encoded duration, note/control pair.
    .byte $38, $19 // FF66; Encoded duration, note/control pair.
    .byte $1c, $1d // FF68; Encoded duration, note/control pair.
    .byte $1c, $19 // FF6A; Encoded duration, note/control pair.
    .byte $38, $14 // FF6C; Encoded duration, note/control pair.
    .byte $38, $1d // FF6E; Encoded duration, note/control pair.
    .byte $38, $19 // FF70; Encoded duration, note/control pair.
    .byte $1c, $1d // FF72; Encoded duration, note/control pair.
    .byte $1c, $19 // FF74; Encoded duration, note/control pair.
    .byte $38, $14 // FF76; Encoded duration, note/control pair.
    .byte $38, $19 // FF78; Encoded duration, note/control pair.
    .byte $70, $1d // FF7A; Encoded duration, note/control pair.
    .byte $38, $19 // FF7C; Encoded duration, note/control pair.
    .byte $38, $14 // FF7E; Encoded duration, note/control pair.
    .byte $38, $19 // FF80; Encoded duration, note/control pair.
    .byte $1c, $1d // FF82; Encoded duration, note/control pair.
    .byte $1c, $19 // FF84; Encoded duration, note/control pair.
    .byte $38, $14 // FF86; Encoded duration, note/control pair.
    .byte $38, $1d // FF88; Encoded duration, note/control pair.
    .byte $38, $19 // FF8A; Encoded duration, note/control pair.
    .byte $1c, $1d // FF8C; Encoded duration, note/control pair.
    .byte $1c, $19 // FF8E; Encoded duration, note/control pair.
    .byte $38, $14 // FF90; Encoded duration, note/control pair.
    .byte $38, $1d // FF92; Encoded duration, note/control pair.
    .byte $38, $19 // FF94; Encoded duration, note/control pair.
    .byte $1c, $1d // FF96; Encoded duration, note/control pair.
    .byte $1c, $19 // FF98; Encoded duration, note/control pair.
    .byte $31, $14 // FF9A; Encoded duration, note/control pair.
    .byte $07, $00 // FF9C; Encoded duration, note/control pair.
    .byte $38, $14 // FF9E; Encoded duration, note/control pair.
    .byte $a8, $19 // FFA0; Encoded duration, note/control pair.
    .byte $00, $00 // FFA2; Stream end: duration=0, note=0.

Tune7Pointers:
    .word Tune7Voice0, SilentTuneStream, SilentTuneStream // FFA4; Tune 7: voice 0,1,2 stream pointers.

Tune7Voice0:
    .byte $8f, $16 // FFAA; Encoded duration, note/control pair.
    .byte $fe, $0f // FFAC; Encoded duration, note/control pair.
    .byte $00, $00 // FFAE; Stream end: duration=0, note=0.

Tune8Pointers:
    .word Tune8Voice0, SilentTuneStream, SilentTuneStream // FFB0; Tune 8: voice 0,1,2 stream pointers.

Tune8Voice0:
    .byte $74, $14 // FFB6; Encoded duration, note/control pair.
    .byte $0a, $00 // FFB8; Encoded duration, note/control pair.
    .byte $2a, $14 // FFBA; Encoded duration, note/control pair.
    .byte $ff, $19 // FFBC; Encoded duration, note/control pair.
    .byte $f9, $19 // FFBE; Encoded duration, note/control pair.
    .byte $7e, $14 // FFC0; Encoded duration, note/control pair.
    .byte $2a, $19 // FFC2; Encoded duration, note/control pair.
    .byte $ff, $1d // FFC4; Encoded duration, note/control pair.
    .byte $f9, $1d // FFC6; Encoded duration, note/control pair.
    .byte $54, $14 // FFC8; Encoded duration, note/control pair.
    .byte $54, $19 // FFCA; Encoded duration, note/control pair.
    .byte $a8, $1d // FFCC; Encoded duration, note/control pair.
    .byte $54, $14 // FFCE; Encoded duration, note/control pair.
    .byte $54, $19 // FFD0; Encoded duration, note/control pair.
    .byte $a8, $1d // FFD2; Encoded duration, note/control pair.
    .byte $54, $14 // FFD4; Encoded duration, note/control pair.
    .byte $54, $19 // FFD6; Encoded duration, note/control pair.
    .byte $ff, $1d // FFD8; Encoded duration, note/control pair.
    .byte $f9, $1d // FFDA; Encoded duration, note/control pair.
    .byte $7e, $19 // FFDC; Encoded duration, note/control pair.
    .byte $2a, $1d // FFDE; Encoded duration, note/control pair.
    .byte $a8, $20 // FFE0; Encoded duration, note/control pair.
    .byte $a8, $20 // FFE2; Encoded duration, note/control pair.
    .byte $a8, $1d // FFE4; Encoded duration, note/control pair.
    .byte $a8, $19 // FFE6; Encoded duration, note/control pair.
    .byte $ff, $14 // FFE8; Encoded duration, note/control pair.
    .byte $ef, $14 // FFEA; Encoded duration, note/control pair.
    .byte $0a, $00 // FFEC; Encoded duration, note/control pair.
    .byte $74, $14 // FFEE; Encoded duration, note/control pair.
    .byte $0a, $00 // FFF0; Encoded duration, note/control pair.
    .byte $2a, $14 // FFF2; Encoded duration, note/control pair.
    .byte $ff, $19 // FFF4; Encoded duration, note/control pair.
    .byte $fe, $19 // FFF6; Encoded duration, note/control pair.
    .byte $00, $00 // FFF8; Stream end: duration=0, note=0.
.assert "72_tune_data end", *, $0fffa
