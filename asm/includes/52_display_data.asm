// Fixed messages, command labels, format selectors, and segment glyphs
// Original CPU range $f7f8-$f8cd.
.assert "52_display_data start", *, $f7f8

DisplayPresetGlyph3:
    .byte $f6 // F7F8; Message 00 Song: glyph 3.
    .byte $9e // F7F9; Message 01 SPEE: glyph 3.
    .byte $1e // F7FA; Message 02 SEnt: glyph 3.
    .byte $1e // F7FB; Message 03 StAt: glyph 3.
    .byte $9e // F7FC; Message 04 notE: glyph 3.
    .byte $9c // F7FD; Message 05 CLOC: glyph 3.
    .byte $2a // F7FE; Message 06 LErn: glyph 3.
    .byte $f6 // F7FF; Message 07 Prog: glyph 3.
    .byte $2a // F800; Message 08 run: glyph 3.
    .byte $76 // F801; Message 09 PLAy: glyph 3.
    .byte $0a // F802; Message 10 CLr: glyph 3.
    .byte $ce // F803; Message 11 CLrP: glyph 3.
    .byte $1c // F804; Message 12 FULL: glyph 3.
    .byte $1c // F805; Message 13 StAL: glyph 3.
    .byte $7a // F806; Message 14 End: glyph 3.
    .byte $f6 // F807; Message 15 bEg: glyph 3.
    .byte $1e // F808; Message 16 init: glyph 3.
    .byte $8e // F809; Message 17 AEoF: glyph 3.
    .byte $2a // F80A; Message 18 AEon: glyph 3.
    .byte $0a // F80B; Message 19 SEr: glyph 3.
    .byte $0a // F80C; Message 20 PAr: glyph 3.
    .byte $2a // F80D; Message 21 Pdon: glyph 3.
    .byte $8e // F80E; Message 22 PdoF: glyph 3.
    .byte $8e // F80F; Message 23 EdoF: glyph 3.
    .byte $2a // F810; Message 24 Edon: glyph 3.
    .byte $2a // F811; Message 25 UCon: glyph 3.
    .byte $8e // F812; Message 26 UCoF: glyph 3.
    .byte $2a // F813; Message 27 Ebon: glyph 3.
    .byte $8e // F814; Message 28 EboF: glyph 3.
    .byte $2a // F815; Message 29 SPon: glyph 3.
    .byte $8e // F816; Message 30 SPoF: glyph 3.
    .byte $7a // F817; Message 31 bAd: glyph 3.

DisplayPresetGlyph2:
    .byte $c4 // F818; Message 00 Song: glyph 2.
    .byte $9e // F819; Message 01 SPEE: glyph 2.
    .byte $2a // F81A; Message 02 SEnt: glyph 2.
    .byte $ee // F81B; Message 03 StAt: glyph 2.
    .byte $1e // F81C; Message 04 notE: glyph 2.
    .byte $fc // F81D; Message 05 CLOC: glyph 2.
    .byte $0a // F81E; Message 06 LErn: glyph 2.
    .byte $c6 // F81F; Message 07 Prog: glyph 2.
    .byte $38 // F820; Message 08 run: glyph 2.
    .byte $ee // F821; Message 09 PLAy: glyph 2.
    .byte $1c // F822; Message 10 CLr: glyph 2.
    .byte $0a // F823; Message 11 CLrP: glyph 2.
    .byte $1c // F824; Message 12 FULL: glyph 2.
    .byte $ee // F825; Message 13 StAL: glyph 2.
    .byte $2a // F826; Message 14 End: glyph 2.
    .byte $9e // F827; Message 15 bEg: glyph 2.
    .byte $20 // F828; Message 16 init: glyph 2.
    .byte $3a // F829; Message 17 AEoF: glyph 2.
    .byte $3a // F82A; Message 18 AEon: glyph 2.
    .byte $9e // F82B; Message 19 SEr: glyph 2.
    .byte $ee // F82C; Message 20 PAr: glyph 2.
    .byte $3a // F82D; Message 21 Pdon: glyph 2.
    .byte $3a // F82E; Message 22 PdoF: glyph 2.
    .byte $3a // F82F; Message 23 EdoF: glyph 2.
    .byte $3a // F830; Message 24 Edon: glyph 2.
    .byte $3a // F831; Message 25 UCon: glyph 2.
    .byte $3a // F832; Message 26 UCoF: glyph 2.
    .byte $3a // F833; Message 27 Ebon: glyph 2.
    .byte $3a // F834; Message 28 EboF: glyph 2.
    .byte $3a // F835; Message 29 SPon: glyph 2.
    .byte $3a // F836; Message 30 SPoF: glyph 2.
    .byte $ee // F837; Message 31 bAd: glyph 2.

DisplayPresetGlyph1:
    .byte $c6 // F838; Message 00 Song: glyph 1.
    .byte $ce // F839; Message 01 SPEE: glyph 1.
    .byte $9e // F83A; Message 02 SEnt: glyph 1.
    .byte $1e // F83B; Message 03 StAt: glyph 1.
    .byte $3a // F83C; Message 04 notE: glyph 1.
    .byte $1c // F83D; Message 05 CLOC: glyph 1.
    .byte $9e // F83E; Message 06 LErn: glyph 1.
    .byte $84 // F83F; Message 07 Prog: glyph 1.
    .byte $0a // F840; Message 08 run: glyph 1.
    .byte $1c // F841; Message 09 PLAy: glyph 1.
    .byte $9c // F842; Message 10 CLr: glyph 1.
    .byte $1c // F843; Message 11 CLrP: glyph 1.
    .byte $7c // F844; Message 12 FULL: glyph 1.
    .byte $1e // F845; Message 13 StAL: glyph 1.
    .byte $9e // F846; Message 14 End: glyph 1.
    .byte $3e // F847; Message 15 bEg: glyph 1.
    .byte $2a // F848; Message 16 init: glyph 1.
    .byte $9e // F849; Message 17 AEoF: glyph 1.
    .byte $9e // F84A; Message 18 AEon: glyph 1.
    .byte $b6 // F84B; Message 19 SEr: glyph 1.
    .byte $ce // F84C; Message 20 PAr: glyph 1.
    .byte $7a // F84D; Message 21 Pdon: glyph 1.
    .byte $7a // F84E; Message 22 PdoF: glyph 1.
    .byte $7a // F84F; Message 23 EdoF: glyph 1.
    .byte $7a // F850; Message 24 Edon: glyph 1.
    .byte $9c // F851; Message 25 UCon: glyph 1.
    .byte $9c // F852; Message 26 UCoF: glyph 1.
    .byte $3e // F853; Message 27 Ebon: glyph 1.
    .byte $3e // F854; Message 28 EboF: glyph 1.
    .byte $ce // F855; Message 29 SPon: glyph 1.
    .byte $ce // F856; Message 30 SPoF: glyph 1.
    .byte $3e // F857; Message 31 bAd: glyph 1.

DisplayPresetGlyph0:
    .byte $b6 // F858; Message 00 Song: glyph 0.
    .byte $b6 // F859; Message 01 SPEE: glyph 0.
    .byte $b6 // F85A; Message 02 SEnt: glyph 0.
    .byte $b6 // F85B; Message 03 StAt: glyph 0.
    .byte $2a // F85C; Message 04 notE: glyph 0.
    .byte $9c // F85D; Message 05 CLOC: glyph 0.
    .byte $1c // F85E; Message 06 LErn: glyph 0.
    .byte $ce // F85F; Message 07 Prog: glyph 0.
    .byte $00 // F860; Message 08 run: glyph 0.
    .byte $ce // F861; Message 09 PLAy: glyph 0.
    .byte $00 // F862; Message 10 CLr: glyph 0.
    .byte $9c // F863; Message 11 CLrP: glyph 0.
    .byte $8e // F864; Message 12 FULL: glyph 0.
    .byte $b6 // F865; Message 13 StAL: glyph 0.
    .byte $00 // F866; Message 14 End: glyph 0.
    .byte $00 // F867; Message 15 bEg: glyph 0.
    .byte $20 // F868; Message 16 init: glyph 0.
    .byte $ee // F869; Message 17 AEoF: glyph 0.
    .byte $ee // F86A; Message 18 AEon: glyph 0.
    .byte $00 // F86B; Message 19 SEr: glyph 0.
    .byte $00 // F86C; Message 20 PAr: glyph 0.
    .byte $ce // F86D; Message 21 Pdon: glyph 0.
    .byte $ce // F86E; Message 22 PdoF: glyph 0.
    .byte $9e // F86F; Message 23 EdoF: glyph 0.
    .byte $9e // F870; Message 24 Edon: glyph 0.
    .byte $7c // F871; Message 25 UCon: glyph 0.
    .byte $7c // F872; Message 26 UCoF: glyph 0.
    .byte $9e // F873; Message 27 Ebon: glyph 0.
    .byte $9e // F874; Message 28 EboF: glyph 0.
    .byte $b6 // F875; Message 29 SPon: glyph 0.
    .byte $b6 // F876; Message 30 SPoF: glyph 0.
    .byte $00 // F877; Message 31 bAd: glyph 0.

CommandGlyph0:
    .byte $1c, $8e, $3e, $0a, $7c, $7c, $ee, $ee // F878; First command-label glyphs.
    .byte $9c, $9c, $6e, $00, $7a, $b6, $b6, $b6 // F880
    .byte $ce // F888

CommandGlyph2:
    .byte $00, $00, $00, $00, $00, $00, $00, $00 // F889; Additional command-label glyphs.
    .byte $00, $3a, $00, $00, $00, $00 // F891

CommandGlyph1:
    .byte $00, $00, $00, $00, $38, $7a, $38, $7a // F897; Second command-label glyphs.
    .byte $0a, $1a, $1c, $00, $00, $2a, $00, $b6 // F89F
    .byte $b6, $00, $00 // F8A7

CommandFormatSelectors:
    .byte $80, $00, $00, $80, $80, $80, $80, $80 // F8AA; Command formatting selectors.
    .byte $80, $40, $40, $00, $00, $40, $00, $80 // F8B2
    .byte $80, $40, $80, $00 // F8BA

DigitSegmentGlyphs:
    .byte $fc, $60, $da, $f2, $66, $b6, $be, $e0 // F8BE; Digit glyphs 0..F; bit 0 is decimal point. Stock 9 lacks bottom segment.
    .byte $fe, $e6, $ee, $3e, $9c, $7a, $9e, $8e // F8C6
.assert "52_display_data end", *, $0f8ce
