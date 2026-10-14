// Remote event handling and foreground mode/submenu selection
// Original CPU range $e617-$e6cd.
.assert "12_remote_ui start", *, $e617

// Remote UI dispatch; may enter another mode instead of returning.
ReadRemoteAndHandleModes:
    jsr PollRobotAndRemote                                 // E617
    cpx #$80                                               // E61A
    beq ReadRemoteAndHandleModes                           // E61C
    cpx #$20                                               // E61E
    bmi L_E623                                             // E620

L_E622:
    rts                                                    // E622

L_E623:
    cpx #$15                                               // E623
    bne L_E645                                             // E625
    lda ZP_MODE                                            // E627
    cmp #$02                                               // E629
    beq L_E631                                             // E62B
    cmp #$01                                               // E62D
    bne L_E645                                             // E62F

L_E631:
    bit ZP_UI_FLAGS                                        // E631
    bvc L_E63C                                             // E633
    lda ZP_SPEED_GAME_TIMER                                // E635
    beq L_E63C                                             // E637
    jsr ClearEntireProgram                                 // E639

L_E63C:
    lda ZP_UI_FLAGS                                        // E63C
    and #$bf                                               // E63E
    sta ZP_UI_FLAGS                                        // E640
    jmp ReadRemoteAndHandleModes                           // E642

L_E645:
    lda.abs RemoteActionMap, x                             // E645
    bmi L_E69F                                             // E648
    cmp #$40                                               // E64A
    bmi L_E622                                             // E64C
    and #$07                                               // E64E
    tax                                                    // E650
    lda ZP_CLAW_STATUS                                     // E651
    and #$0c                                               // E653
    ora ZP_MOTOR_STATUS                                    // E655
    bne L_E622                                             // E657
    cpx #$06                                               // E659
    bne L_E66B                                             // E65B
    lda ZP_MODE                                            // E65D
    bne L_E694                                             // E65F
    lda ZP_SUBMENU                                         // E661
    cmp #$06                                               // E663
    bne L_E689                                             // E665
    ldx #$04                                               // E667
    bne L_E689                                             // E669

L_E66B:
    cpx #$03                                               // E66B
    bne L_E679                                             // E66D
    lda ZP_SUBMENU                                         // E66F
    cmp #$03                                               // E671
    bne L_E689                                             // E673
    ldx #$02                                               // E675
    bne L_E689                                             // E677

L_E679:
    cpx #$01                                               // E679
    bne L_E689                                             // E67B
    lda ZP_SUBMENU                                         // E67D
    cmp #$01                                               // E67F
    bne L_E689                                             // E681
    lda ZP_MODE                                            // E683
    bne L_E689                                             // E685
    ldx #$05                                               // E687

L_E689:
    txa                                                    // E689
    beq L_E697                                             // E68A
    dex                                                    // E68C
    jsr DisplayPreset                                      // E68D
    inx                                                    // E690

L_E691:
    stx ZP_SUBMENU                                         // E691
    rts                                                    // E693

L_E694:
    jmp PlayErrorTone                                      // E694

L_E697:
    lda #$e0                                               // E697
    jsr SendHeadByte                                       // E699
    jmp L_E691                                             // E69C

L_E69F:
    and #$07                                               // E69F
    jmp EnterForegroundMode                                // E6A1

// Run motor/service polling, wheel-speed adjustment, then consume remote mailbox.
PollRobotAndRemote:
    jsr PollMotorProgressAndService                        // E6A4
    jsr RampWheelSpeed                                     // E6A7
    lda #$80                                               // E6AA
    ldx ZP_REMOTE_MAILBOX                                  // E6AC
    bmi L_E6B4                                             // E6AE
    sta ZP_REMOTE_MAILBOX                                  // E6B0
    stx ZP_KEY                                             // E6B2

L_E6B4:
    rts                                                    // E6B4

RemoteActionMap:
    .byte $00 // E6B5; Remote key index 0; encoded UI/mode action, not raw RF payload.
    .byte $01 // E6B6; Remote key index 1; encoded UI/mode action, not raw RF payload.
    .byte $02 // E6B7; Remote key index 2; encoded UI/mode action, not raw RF payload.
    .byte $03 // E6B8; Remote key index 3; encoded UI/mode action, not raw RF payload.
    .byte $04 // E6B9; Remote key index 4; encoded UI/mode action, not raw RF payload.
    .byte $05 // E6BA; Remote key index 5; encoded UI/mode action, not raw RF payload.
    .byte $06 // E6BB; Remote key index 6; encoded UI/mode action, not raw RF payload.
    .byte $07 // E6BC; Remote key index 7; encoded UI/mode action, not raw RF payload.
    .byte $08 // E6BD; Remote key index 8; encoded UI/mode action, not raw RF payload.
    .byte $09 // E6BE; Remote key index 9; encoded UI/mode action, not raw RF payload.
    .byte $0a // E6BF; Remote key index 10; encoded UI/mode action, not raw RF payload.
    .byte $0b // E6C0; Remote key index 11; encoded UI/mode action, not raw RF payload.
    .byte $0c // E6C1; Remote key index 12; encoded UI/mode action, not raw RF payload.
    .byte $0d // E6C2; Remote key index 13; encoded UI/mode action, not raw RF payload.
    .byte $0e // E6C3; Remote key index 14; encoded UI/mode action, not raw RF payload.
    .byte $0f // E6C4; Remote key index 15; encoded UI/mode action, not raw RF payload.
    .byte $41 // E6C5; Remote key index 16; encoded UI/mode action, not raw RF payload.
    .byte $46 // E6C6; Remote key index 17; encoded UI/mode action, not raw RF payload.
    .byte $43 // E6C7; Remote key index 18; encoded UI/mode action, not raw RF payload.
    .byte $13 // E6C8; Remote key index 19; encoded UI/mode action, not raw RF payload.
    .byte $84 // E6C9; Remote key index 20; encoded UI/mode action, not raw RF payload.
    .byte $82 // E6CA; Remote key index 21; encoded UI/mode action, not raw RF payload.
    .byte $81 // E6CB; Remote key index 22; encoded UI/mode action, not raw RF payload.
    .byte $83 // E6CC; Remote key index 23; encoded UI/mode action, not raw RF payload.
    .byte $80 // E6CD; Remote key index 24; encoded UI/mode action, not raw RF payload.
.assert "12_remote_ui end", *, $0e6ce
