// Immediate/programmed motion, homing, completion, and position bookkeeping
// Original CPU range $e6ce-$ed47.
.assert "20_motors start", *, $e6ce

// Immediate/LEARN operation handling, motor status and direction commands.
HandleImmediateMotion:
    tax                                                    // E6CE
    bne L_E6EF                                             // E6CF
    lda ZP_MOTOR_STATUS                                    // E6D1
    and #$0f                                               // E6D3
    bne L_E74E                                             // E6D5
    lda ZP_MOTOR_DIRECTION                                 // E6D7
    lsr                                                    // E6D9
    bcc L_E6E6                                             // E6DA
    lda ZP_MOTOR_STATUS                                    // E6DC
    ora #$02                                               // E6DE
    sta ZP_MOTOR_STATUS                                    // E6E0
    lda #$e5                                               // E6E2
    bne L_E71F                                             // E6E4

L_E6E6:
    lsr ZP_MOTOR_STATUS                                    // E6E6
    sec                                                    // E6E8
    rol ZP_MOTOR_STATUS                                    // E6E9
    lda #$d5                                               // E6EB
    bne L_E71F                                             // E6ED

L_E6EF:
    lda ZP_MOTOR_STATUS                                    // E6EF
    dex                                                    // E6F1
    bne L_E6FE                                             // E6F2
    and #$0f                                               // E6F4
    bne L_E74E                                             // E6F6
    jsr StartForwardWheels                                 // E6F8
    jmp RecordLearnMotion                                  // E6FB

L_E6FE:
    dex                                                    // E6FE
    bne L_E70B                                             // E6FF
    and #$0f                                               // E701
    bne L_E74E                                             // E703
    jsr StartReverseWheels                                 // E705
    jmp RecordLearnMotion                                  // E708

L_E70B:
    dex                                                    // E70B
    bne L_E733                                             // E70C
    and #$0f                                               // E70E
    bne L_E74E                                             // E710
    lda ZP_MOTOR_DIRECTION                                 // E712
    lsr                                                    // E714
    bcc L_E729                                             // E715
    lda ZP_MOTOR_STATUS                                    // E717
    ora #$08                                               // E719
    sta ZP_MOTOR_STATUS                                    // E71B
    lda #$e4                                               // E71D

L_E71F:
    jsr SendMotorSpeed                                     // E71F
    lda #$ff                                               // E722
    sta ZP_SPEED_GAME_TIMER                                // E724
    jmp RecordLearnMotion                                  // E726

L_E729:
    lda ZP_MOTOR_STATUS                                    // E729
    ora #$04                                               // E72B
    sta ZP_MOTOR_STATUS                                    // E72D
    lda #$d4                                               // E72F
    bne L_E71F                                             // E731

L_E733:
    dex                                                    // E733
    bne L_E74F                                             // E734
    and #$30                                               // E736
    bne L_E74E                                             // E738
    bit ZP_MOTION_INHIBIT                                  // E73A
    bvs L_E74E                                             // E73C
    lda ZP_MOTOR_STATUS                                    // E73E
    ora #$10                                               // E740
    sta ZP_MOTOR_STATUS                                    // E742
    lda ZP_MOTOR_DIRECTION                                 // E744
    and #$ef                                               // E746
    sta ZP_MOTOR_DIRECTION                                 // E748
    lda #$12                                               // E74A
    bne L_E794                                             // E74C

L_E74E:
    rts                                                    // E74E

L_E74F:
    dex                                                    // E74F
    bne L_E76A                                             // E750
    and #$30                                               // E752
    bne L_E74E                                             // E754
    bit ZP_MOTION_INHIBIT                                  // E756
    bmi L_E74E                                             // E758
    lda ZP_MOTOR_STATUS                                    // E75A
    ora #$20                                               // E75C
    sta ZP_MOTOR_STATUS                                    // E75E
    lda ZP_MOTOR_DIRECTION                                 // E760
    ora #$10                                               // E762
    sta ZP_MOTOR_DIRECTION                                 // E764
    lda #$22                                               // E766
    bne L_E794                                             // E768

L_E76A:
    lda ZP_FEATURE_FLAGS                                   // E76A
    lsr                                                    // E76C
    lda ZP_MOTOR_STATUS                                    // E76D
    dex                                                    // E76F
    bne L_E79A                                             // E770
    and #$f0                                               // E772
    bcc L_E778                                             // E774
    and #$c0                                               // E776

L_E778:
    bne L_E74E                                             // E778
    bit ZP_MOTION_INHIBIT                                  // E77A
    bvs L_E74E                                             // E77C
    lda ZP_MOTOR_STATUS                                    // E77E
    bcs L_E784                                             // E780
    ora #$60                                               // E782

L_E784:
    ora #$40                                               // E784
    sta ZP_MOTOR_STATUS                                    // E786
    lda ZP_MOTOR_DIRECTION                                 // E788
    and #$bf                                               // E78A
    bcs L_E790                                             // E78C
    ora #$10                                               // E78E

L_E790:
    sta ZP_MOTOR_DIRECTION                                 // E790
    lda #$11                                               // E792

L_E794:
    jsr SendMotorByte                                      // E794
    jmp RecordLearnMotion                                  // E797

L_E79A:
    dex                                                    // E79A
    bne L_E7C1                                             // E79B
    and #$f0                                               // E79D
    bcc L_E7A3                                             // E79F
    and #$c0                                               // E7A1

L_E7A3:
    bne L_E74E                                             // E7A3
    bit ZP_MOTION_INHIBIT                                  // E7A5
    bmi L_E74E                                             // E7A7
    lda ZP_MOTOR_STATUS                                    // E7A9
    bcs L_E7AF                                             // E7AB
    ora #$90                                               // E7AD

L_E7AF:
    ora #$80                                               // E7AF
    sta ZP_MOTOR_STATUS                                    // E7B1
    lda ZP_MOTOR_DIRECTION                                 // E7B3
    ora #$40                                               // E7B5
    bcs L_E7BB                                             // E7B7
    and #$ef                                               // E7B9

L_E7BB:
    sta ZP_MOTOR_DIRECTION                                 // E7BB
    lda #$21                                               // E7BD
    bne L_E794                                             // E7BF

L_E7C1:
    dex                                                    // E7C1
    bne L_E7D9                                             // E7C2
    lda #$b1                                               // E7C4
    jsr ReadMotorReply                                     // E7C6
    sta ZP_CLAW_STATUS                                     // E7C9
    and #$0c                                               // E7CB
    bne L_E7A3                                             // E7CD
    lda ZP_CLAW_STATUS                                     // E7CF
    ora #$08                                               // E7D1
    sta ZP_CLAW_STATUS                                     // E7D3
    lda #$20                                               // E7D5
    bne L_E794                                             // E7D7

L_E7D9:
    dex                                                    // E7D9
    bne L_E80C                                             // E7DA
    lda #$b1                                               // E7DC
    jsr ReadMotorReply                                     // E7DE
    sta ZP_CLAW_STATUS                                     // E7E1
    and #$0c                                               // E7E3
    bne L_E7A3                                             // E7E5
    lda ZP_CLAW_STATUS                                     // E7E7
    ora #$04                                               // E7E9
    sta ZP_CLAW_STATUS                                     // E7EB
    lda ZP_MOTOR_AUX                                       // E7ED
    eor #$04                                               // E7EF
    sta ZP_MOTOR_AUX                                       // E7F1
    and #$04                                               // E7F3
    beq L_E800                                             // E7F5
    lda #$50                                               // E7F7
    jsr SendMotorByte                                      // E7F9

L_E7FC:
    lda #$00                                               // E7FC
    beq L_E807                                             // E7FE

L_E800:
    lda #$70                                               // E800
    jsr SendMotorByte                                      // E802

L_E805:
    lda #$01                                               // E805

L_E807:
    sta ZP_OPERAND                                         // E807
    jmp InsertCurrentCommandIfLearning                     // E809

L_E80C:
    dex                                                    // E80C
    bne L_E81D                                             // E80D
    bit ZP_HEADLAMP_STATE                                  // E80F
    bvc L_E818                                             // E811
    jsr SetHeadlampOff                                     // E813
    beq L_E7FC                                             // E816

L_E818:
    jsr SetHeadlampOn                                      // E818
    bne L_E805                                             // E81B

L_E81D:
    dex                                                    // E81D
    bne L_E829                                             // E81E
    jsr HomeRobot                                          // E820
    jsr PlayFeedbackTone3C                                 // E823
    jmp RecordLearnMotion                                  // E826

L_E829:
    dex                                                    // E829
    bne L_E833                                             // E82A
    lda #$ff                                               // E82C
    sta ZP_DELAY_TIMER                                     // E82E
    jmp RecordLearnMotion                                  // E830

L_E833:
    dex                                                    // E833
    dex                                                    // E834
    dex                                                    // E835
    dex                                                    // E836
    bne L_E849                                             // E837
    and #$0c                                               // E839
    bne L_E85C                                             // E83B
    lda ZP_MOTOR_STATUS                                    // E83D
    and #$03                                               // E83F
    beq L_E85C                                             // E841

L_E843:
    jsr StopWheels                                         // E843
    jmp UpdateLearnOperand                                 // E846

L_E849:
    dex                                                    // E849
    bne L_E853                                             // E84A
    and #$0f                                               // E84C
    cmp #$05                                               // E84E
    beq L_E843                                             // E850
    rts                                                    // E852

L_E853:
    dex                                                    // E853
    bne L_E85D                                             // E854
    and #$0f                                               // E856
    cmp #$0a                                               // E858
    beq L_E843                                             // E85A

L_E85C:
    rts                                                    // E85C

L_E85D:
    dex                                                    // E85D
    bne L_E86B                                             // E85E
    and #$03                                               // E860
    bne L_E86A                                             // E862
    lda ZP_MOTOR_STATUS                                    // E864
    and #$0c                                               // E866
    bne L_E843                                             // E868

L_E86A:
    rts                                                    // E86A

L_E86B:
    dex                                                    // E86B
    bne L_E897                                             // E86C
    and #$10                                               // E86E
    beq L_E86A                                             // E870

L_E872:
    lda ZP_FEATURE_FLAGS                                   // E872
    lsr                                                    // E874
    bcs L_E87D                                             // E875
    lda ZP_MOTOR_STATUS                                    // E877
    and #$c0                                               // E879
    bne L_E86A                                             // E87B

L_E87D:
    lda ZP_PRIOR_MOTOR_STATUS                              // E87D
    and #$cf                                               // E87F
    sta ZP_PRIOR_MOTOR_STATUS                              // E881
    lda #$02                                               // E883
    jsr SendMotorByte                                      // E885
    jsr MotorSettlingDelay                                 // E888
    jsr FinalizeWristPosition                              // E88B
    lda ZP_MOTOR_STATUS                                    // E88E
    and #$cf                                               // E890
    sta ZP_MOTOR_STATUS                                    // E892
    jmp UpdateLearnOperand                                 // E894

L_E897:
    dex                                                    // E897
    bne L_E89F                                             // E898
    and #$20                                               // E89A
    bne L_E872                                             // E89C

L_E89E:
    rts                                                    // E89E

L_E89F:
    dex                                                    // E89F
    bne L_E8D2                                             // E8A0
    and #$40                                               // E8A2
    beq L_E89E                                             // E8A4

L_E8A6:
    lda #$01                                               // E8A6
    jsr SendMotorByte                                      // E8A8
    jsr MotorSettlingDelay                                 // E8AB
    jsr FinalizeArmPosition                                // E8AE
    lda ZP_FEATURE_FLAGS                                   // E8B1
    lsr                                                    // E8B3
    php                                                    // E8B4
    bcs L_E8BA                                             // E8B5
    jsr FinalizeWristPosition                              // E8B7

L_E8BA:
    lda ZP_PRIOR_MOTOR_STATUS                              // E8BA
    plp                                                    // E8BC
    bcs L_E8C1                                             // E8BD
    and #$0f                                               // E8BF

L_E8C1:
    and #$3f                                               // E8C1
    sta ZP_PRIOR_MOTOR_STATUS                              // E8C3
    lda ZP_MOTOR_STATUS                                    // E8C5
    bcs L_E8CB                                             // E8C7
    and #$0f                                               // E8C9

L_E8CB:
    and #$3f                                               // E8CB
    sta ZP_MOTOR_STATUS                                    // E8CD
    jmp UpdateLearnOperand                                 // E8CF

L_E8D2:
    dex                                                    // E8D2
    bne L_E8D9                                             // E8D3
    asl                                                    // E8D5
    bcs L_E8A6                                             // E8D6

L_E8D8:
    rts                                                    // E8D8

L_E8D9:
    dex                                                    // E8D9
    bne L_E8FC                                             // E8DA
    lda ZP_CLAW_STATUS                                     // E8DC
    and #$08                                               // E8DE
    beq L_E8D8                                             // E8E0
    lda ZP_PRIOR_CLAW_STATUS                               // E8E2
    and #$f7                                               // E8E4
    sta ZP_PRIOR_CLAW_STATUS                               // E8E6
    lda #$00                                               // E8E8
    jsr SendMotorByte                                      // E8EA
    jsr MotorSettlingDelay                                 // E8ED
    jsr FinalizeClawPosition                               // E8F0
    lda ZP_CLAW_STATUS                                     // E8F3
    and #$f7                                               // E8F5
    sta ZP_CLAW_STATUS                                     // E8F7
    jmp UpdateLearnOperand                                 // E8F9

L_E8FC:
    lda ZP_DELAY_TIMER                                     // E8FC
    eor #$ff                                               // E8FE
    sta ZP_TEMP_VALUE                                      // E900
    jmp UpdateLearnOperand                                 // E902

// Stop command depends on coupling; delay, reconcile four positions, then handshake.
StopAllMotors:
    lda #$08                                               // E905
    sta.abs IO_COP_CONTROL_STATUS                          // E907
    lda ZP_CLAW_STATUS                                     // E90A
    and #$f1                                               // E90C
    sta ZP_CLAW_STATUS                                     // E90E
    jsr SetHeadlampOff                                     // E910
    sta ZP_MOTOR_STATUS                                    // E913
    sta ZP_PRIOR_MOTOR_STATUS                              // E915
    sta ZP_PRIOR_CLAW_STATUS                               // E917
    sta ZP_WHEEL_SPEED                                     // E919
    lda #$18                                               // E91B
    sta.abs IO_COP_CONTROL_STATUS                          // E91D
    lda ZP_FEATURE_FLAGS                                   // E920
    lsr                                                    // E922
    lda #$f8                                               // E923
    bcs L_E928                                             // E925
    asl                                                    // E927

L_E928:
    jsr SendMotorByte                                      // E928
    jsr MotorSettlingDelay                                 // E92B
    jsr FinalizeWheelPosition                              // E92E
    jsr FinalizeWristPosition                              // E931
    jsr FinalizeArmPosition                                // E934
    jsr FinalizeClawPosition                               // E937
    jmp WaitMotorHandshakeHigh                             // E93A

// Send wheel-stop byte, delay, reconcile position, clear wheel status/speed.
StopWheels:
    lda ZP_PRIOR_MOTOR_STATUS                              // E93D
    and #$f0                                               // E93F
    sta ZP_PRIOR_MOTOR_STATUS                              // E941
    lda #$03                                               // E943
    jsr SendMotorByte                                      // E945
    jsr MotorSettlingDelay                                 // E948
    jsr FinalizeWheelPosition                              // E94B
    lda ZP_MOTOR_STATUS                                    // E94E
    and #$f0                                               // E950
    sta ZP_MOTOR_STATUS                                    // E952
    lda #$00                                               // E954
    sta ZP_WHEEL_SPEED                                     // E956

L_E958:
    rts                                                    // E958

// Immediate/LEARN speed change after timer expiry; resends direction and speed parameter.
RampWheelSpeed:
    lda ZP_MODE                                            // E959
    cmp #$02                                               // E95B
    bpl L_E958                                             // E95D
    lda ZP_MOTOR_STATUS                                    // E95F
    and #$0f                                               // E961
    beq L_E958                                             // E963
    lda ZP_WHEEL_SPEED                                     // E965
    bne L_E958                                             // E967
    lda ZP_SPEED_GAME_TIMER                                // E969
    bne L_E958                                             // E96B
    lda #$f4                                               // E96D
    sta ZP_SPEED_GAME_TIMER                                // E96F
    inc ZP_WHEEL_SPEED                                     // E971
    lda ZP_MOTOR_STATUS                                    // E973
    lsr                                                    // E975
    bcc L_E97D                                             // E976
    lda #$d5                                               // E978
    jsr SendMotorSpeed                                     // E97A

L_E97D:
    lda ZP_MOTOR_STATUS                                    // E97D
    and #$02                                               // E97F
    beq L_E988                                             // E981
    lda #$e5                                               // E983
    jsr SendMotorSpeed                                     // E985

L_E988:
    lda ZP_MOTOR_STATUS                                    // E988
    and #$04                                               // E98A
    beq L_E993                                             // E98C
    lda #$d4                                               // E98E
    jsr SendMotorSpeed                                     // E990

L_E993:
    lda ZP_MOTOR_STATUS                                    // E993
    and #$08                                               // E995
    beq L_E958                                             // E997
    lda #$e4                                               // E999
    bne SendMotorSpeed                                     // E99B

// Set wheel direction/status and fall through to speed-command transmission.
StartForwardWheels:
    lda ZP_MOTOR_STATUS                                    // E99D
    and #$f0                                               // E99F
    ora #$05                                               // E9A1
    sta ZP_MOTOR_STATUS                                    // E9A3
    lda ZP_MOTOR_DIRECTION                                 // E9A5
    ora #$02                                               // E9A7
    and #$fe                                               // E9A9
    sta ZP_MOTOR_DIRECTION                                 // E9AB
    lda #$d3                                               // E9AD

L_E9AF:
    ldx #$ff                                               // E9AF
    stx ZP_SPEED_GAME_TIMER                                // E9B1

// Send A, then speed-state+3. Uses common motor serializer.
SendMotorSpeed:
    jsr SendMotorByte                                      // E9B3
    lda ZP_WHEEL_SPEED                                     // E9B6
    clc                                                    // E9B8
    adc #$03                                               // E9B9
    jmp SendMotorByte                                      // E9BB

// Set reverse wheel state and send the reverse speed command.
StartReverseWheels:
    lda ZP_MOTOR_STATUS                                    // E9BE
    and #$fa                                               // E9C0
    ora #$0a                                               // E9C2
    sta ZP_MOTOR_STATUS                                    // E9C4
    lda ZP_MOTOR_DIRECTION                                 // E9C6
    ora #$03                                               // E9C8
    sta ZP_MOTOR_DIRECTION                                 // E9CA
    lda #$e3                                               // E9CC
    bne L_E9AF                                             // E9CE

// Poll B0 until zero and B1 until claw activity bits clear; runs service paths.
WaitForMotorCompletion:
    jsr PollMotorProgressAndService                        // E9D0
    lda #$b0                                               // E9D3
    jsr ReadMotorReply                                     // E9D5
    sta ZP_MOTOR_STATUS                                    // E9D8
    bne WaitForMotorCompletion                             // E9DA
    lda #$b1                                               // E9DC
    jsr ReadMotorReply                                     // E9DE
    sta ZP_CLAW_STATUS                                     // E9E1
    and #$0c                                               // E9E3
    bne WaitForMotorCompletion                             // E9E5
    rts                                                    // E9E7

// Set $2A=$18 and wait for interrupt timer service to decrement it to zero.
MotorSettlingDelay:
    lda #$18                                               // E9E8
    sta ZP_MOTOR_DELAY_TIMER                               // E9EA

L_E9EC:
    lda ZP_MOTOR_DELAY_TIMER                               // E9EC
    bne L_E9EC                                             // E9EE
    rts                                                    // E9F0

// Motor handshake/status path using $1000 bit 7 and command $C1.
MotorHandshakeService:
    jsr PollMotorProgressAndService                        // E9F1
    bit.abs IO_SERIAL_STATUS_HEADLAMP                      // E9F4
    bmi MotorHandshakeService                              // E9F7
    lda #$c1                                               // E9F9
    jmp SendMotorByte                                      // E9FB

// A=operation, $13=operand. Busy/limit checks and hardware handshake precede dispatch.
ExecuteMotorCommand:
    sta ZP_OPERATION_INDEX                                 // E9FE
    bit.abs IO_SERIAL_STATUS_HEADLAMP                      // EA00
    bmi MotorOperationDispatch                             // EA03
    lda #$c1                                               // EA05
    jsr SendMotorByte                                      // EA07
    lda #$30                                               // EA0A
    jsr ReadMotorReply                                     // EA0C
    sta ZP_MOTOR_AUX                                       // EA0F
    lda #$b0                                               // EA11
    jsr ReadMotorReply                                     // EA13
    sta ZP_MOTOR_STATUS                                    // EA16
    and #$c0                                               // EA18
    bne L_EA2C                                             // EA1A
    jsr FinalizeArmPosition                                // EA1C
    lda ZP_FEATURE_FLAGS                                   // EA1F
    lsr                                                    // EA21
    lda ZP_PRIOR_MOTOR_STATUS                              // EA22
    bcs L_EA28                                             // EA24
    and #$0f                                               // EA26

L_EA28:
    and #$3f                                               // EA28
    sta ZP_PRIOR_MOTOR_STATUS                              // EA2A

L_EA2C:
    lda ZP_MOTOR_STATUS                                    // EA2C
    and #$30                                               // EA2E
    bne L_EA3B                                             // EA30
    jsr FinalizeWristPosition                              // EA32
    lda ZP_PRIOR_MOTOR_STATUS                              // EA35
    and #$cf                                               // EA37
    sta ZP_PRIOR_MOTOR_STATUS                              // EA39

L_EA3B:
    lda ZP_MOTOR_STATUS                                    // EA3B
    and #$0f                                               // EA3D
    bne L_EA4A                                             // EA3F
    jsr FinalizeWheelPosition                              // EA41
    lda ZP_PRIOR_MOTOR_STATUS                              // EA44
    and #$f0                                               // EA46
    sta ZP_PRIOR_MOTOR_STATUS                              // EA48

L_EA4A:
    lda #$b1                                               // EA4A
    jsr ReadMotorReply                                     // EA4C
    sta ZP_CLAW_STATUS                                     // EA4F
    and #$0c                                               // EA51
    bne MotorOperationDispatch                             // EA53
    jsr FinalizeClawPosition                               // EA55
    lda ZP_PRIOR_CLAW_STATUS                               // EA58
    and #$f3                                               // EA5A
    sta ZP_PRIOR_CLAW_STATUS                               // EA5C

// Clear rejected bit, ignore negative operation, and skip zero-count moves 0..8.
MotorOperationDispatch:
    asl ZP_MOTION_RESULT                                   // EA5E
    lsr ZP_MOTION_RESULT                                   // EA60
    ldx ZP_OPERATION_INDEX                                 // EA62
    bpl L_EA67                                             // EA64

L_EA66:
    rts                                                    // EA66

L_EA67:
    cpx #$09                                               // EA67
    bpl CheckMotorLeft                                     // EA69
    lda ZP_OPERAND                                         // EA6B
    beq L_EA66                                             // EA6D

// Operation 0: left turn; selected direction depends on saved wheel direction.
CheckMotorLeft:
    txa                                                    // EA6F
    bne CheckMotorForward                                  // EA70
    lda ZP_MOTOR_STATUS                                    // EA72
    and #$0f                                               // EA74
    bne L_EAB0                                             // EA76
    lda ZP_MOTOR_DIRECTION                                 // EA78
    lsr                                                    // EA7A
    bcs L_EA8B                                             // EA7B
    lsr ZP_MOTOR_STATUS                                    // EA7D
    sec                                                    // EA7F
    rol ZP_MOTOR_STATUS                                    // EA80
    lda #$d5                                               // EA82
    jsr SendMotorSpeed                                     // EA84
    lda #$95                                               // EA87
    bne SendMotorCommandAndOperand                         // EA89

L_EA8B:
    lda ZP_MOTOR_STATUS                                    // EA8B
    ora #$02                                               // EA8D
    sta ZP_MOTOR_STATUS                                    // EA8F
    lda #$e5                                               // EA91
    jsr SendMotorSpeed                                     // EA93
    lda #$a5                                               // EA96
    bne SendMotorCommandAndOperand                         // EA98

// Operation 1: forward movement; skip/reject if wheel group is busy.
CheckMotorForward:
    lda ZP_MOTOR_STATUS                                    // EA9A
    dex                                                    // EA9C
    bne CheckMotorReverse                                  // EA9D
    and #$0f                                               // EA9F
    bne L_EAB0                                             // EAA1
    lda ZP_MOTOR_STATUS                                    // EAA3
    ora #$05                                               // EAA5
    sta ZP_MOTOR_STATUS                                    // EAA7
    jsr StartForwardWheels                                 // EAA9
    lda #$93                                               // EAAC
    bne SendMotorCommandAndOperand                         // EAAE

L_EAB0:
    jmp RejectMotorOperation                               // EAB0

// Operation 2: reverse movement.
CheckMotorReverse:
    dex                                                    // EAB3
    bne CheckMotorRight                                    // EAB4
    and #$0f                                               // EAB6
    bne L_EAB0                                             // EAB8
    lda ZP_MOTOR_STATUS                                    // EABA
    ora #$0a                                               // EABC
    sta ZP_MOTOR_STATUS                                    // EABE
    jsr StartReverseWheels                                 // EAC0
    lda #$a3                                               // EAC3

// A=command; send it, then tail-call sender with $13 operand.
SendMotorCommandAndOperand:
    jsr SendMotorByte                                      // EAC5
    lda ZP_OPERAND                                         // EAC8
    jmp SendMotorByte                                      // EACA

// Operation 3: right turn; command depends on saved direction.
CheckMotorRight:
    dex                                                    // EACD
    bne CheckMotorWristUp                                  // EACE
    and #$0f                                               // EAD0
    bne L_EAB0                                             // EAD2
    lda ZP_MOTOR_DIRECTION                                 // EAD4
    lsr                                                    // EAD6
    bcs L_EAE8                                             // EAD7
    lda ZP_MOTOR_STATUS                                    // EAD9
    ora #$04                                               // EADB
    sta ZP_MOTOR_STATUS                                    // EADD
    lda #$d4                                               // EADF
    jsr SendMotorSpeed                                     // EAE1
    lda #$94                                               // EAE4
    bne SendMotorCommandAndOperand                         // EAE6

L_EAE8:
    lda ZP_MOTOR_STATUS                                    // EAE8
    ora #$08                                               // EAEA
    sta ZP_MOTOR_STATUS                                    // EAEC
    lda #$e4                                               // EAEE
    jsr SendMotorSpeed                                     // EAF0
    lda #$a4                                               // EAF3
    bne SendMotorCommandAndOperand                         // EAF5

// Operation 4: wrist-up; activity mask $30 and inhibit bit 6.
CheckMotorWristUp:
    dex                                                    // EAF7
    bne CheckMotorWristDown                                // EAF8
    and #$30                                               // EAFA
    bne L_EAB0                                             // EAFC
    bit ZP_MOTION_INHIBIT                                  // EAFE
    bvs L_EB2D                                             // EB00
    lda ZP_MOTOR_STATUS                                    // EB02
    ora #$10                                               // EB04
    sta ZP_MOTOR_STATUS                                    // EB06
    lda ZP_MOTOR_DIRECTION                                 // EB08
    and #$ef                                               // EB0A
    sta ZP_MOTOR_DIRECTION                                 // EB0C
    lda #$92                                               // EB0E
    bne SendMotorCommandAndOperand                         // EB10

// Operation 5: wrist-down; activity mask $30 and inhibit bit 7.
CheckMotorWristDown:
    dex                                                    // EB12
    bne CheckMotorArmsUp                                   // EB13
    and #$30                                               // EB15
    bne L_EB82                                             // EB17
    bit ZP_MOTION_INHIBIT                                  // EB19
    bmi L_EB2D                                             // EB1B
    lda ZP_MOTOR_STATUS                                    // EB1D
    ora #$20                                               // EB1F
    sta ZP_MOTOR_STATUS                                    // EB21
    lda ZP_MOTOR_DIRECTION                                 // EB23
    ora #$10                                               // EB25
    sta ZP_MOTOR_DIRECTION                                 // EB27
    lda #$a2                                               // EB29
    bne L_EB58                                             // EB2B

L_EB2D:
    rts                                                    // EB2D

// Operation 6: arms-up; coupling flag can add wrist-down activity.
CheckMotorArmsUp:
    lda ZP_FEATURE_FLAGS                                   // EB2E
    lsr                                                    // EB30
    lda ZP_MOTOR_STATUS                                    // EB31
    dex                                                    // EB33
    bne CheckMotorArmsDown                                 // EB34
    and #$f0                                               // EB36
    bcc L_EB3C                                             // EB38
    and #$c0                                               // EB3A

L_EB3C:
    bne L_EB82                                             // EB3C
    bit ZP_MOTION_INHIBIT                                  // EB3E
    bvs L_EB2D                                             // EB40
    lda ZP_MOTOR_STATUS                                    // EB42
    bcs L_EB48                                             // EB44
    ora #$60                                               // EB46

L_EB48:
    ora #$40                                               // EB48
    sta ZP_MOTOR_STATUS                                    // EB4A
    lda ZP_MOTOR_DIRECTION                                 // EB4C
    and #$bf                                               // EB4E
    bcs L_EB54                                             // EB50
    ora #$10                                               // EB52

L_EB54:
    sta ZP_MOTOR_DIRECTION                                 // EB54
    lda #$91                                               // EB56

L_EB58:
    jmp SendMotorCommandAndOperand                         // EB58

// Operation 7: arms-down; coupling flag can add wrist-up activity.
CheckMotorArmsDown:
    dex                                                    // EB5B
    bne CheckMotorClawRotate                               // EB5C
    and #$f0                                               // EB5E
    bcc L_EB64                                             // EB60
    and #$c0                                               // EB62

L_EB64:
    bne L_EB82                                             // EB64
    bit ZP_MOTION_INHIBIT                                  // EB66
    bmi L_EB2D                                             // EB68
    lda ZP_MOTOR_STATUS                                    // EB6A
    bcs L_EB70                                             // EB6C
    ora #$90                                               // EB6E

L_EB70:
    ora #$80                                               // EB70
    sta ZP_MOTOR_STATUS                                    // EB72
    lda ZP_MOTOR_DIRECTION                                 // EB74
    ora #$40                                               // EB76
    bcs L_EB7C                                             // EB78
    and #$ef                                               // EB7A

L_EB7C:
    sta ZP_MOTOR_DIRECTION                                 // EB7C
    lda #$a1                                               // EB7E
    bne L_EB58                                             // EB80

L_EB82:
    jmp RejectMotorOperation                               // EB82

// Operation 8: claw rotation with supplied count.
CheckMotorClawRotate:
    lda ZP_CLAW_STATUS                                     // EB85
    dex                                                    // EB87
    bne CheckMotorClawOpenClose                            // EB88
    and #$0c                                               // EB8A
    bne L_EB82                                             // EB8C
    lda ZP_CLAW_STATUS                                     // EB8E
    ora #$08                                               // EB90
    sta ZP_CLAW_STATUS                                     // EB92
    lda #$a0                                               // EB94
    bne L_EB58                                             // EB96

// Operation 9: one-byte open/close command selected by operand.
CheckMotorClawOpenClose:
    dex                                                    // EB98
    bne CheckMotorHeadlamp                                 // EB99
    and #$0c                                               // EB9B
    bne L_EB82                                             // EB9D
    lda ZP_CLAW_STATUS                                     // EB9F
    ora #$04                                               // EBA1
    sta ZP_CLAW_STATUS                                     // EBA3
    lda ZP_OPERAND                                         // EBA5
    beq L_EBB6                                             // EBA7
    lda ZP_MOTOR_AUX                                       // EBA9
    ora #$04                                               // EBAB
    and #$f7                                               // EBAD
    sta ZP_MOTOR_AUX                                       // EBAF
    lda #$70                                               // EBB1
    jmp SendMotorByte                                      // EBB3

L_EBB6:
    lda ZP_MOTOR_AUX                                       // EBB6
    ora #$08                                               // EBB8
    and #$fb                                               // EBBA
    sta ZP_MOTOR_AUX                                       // EBBC
    lda #$50                                               // EBBE
    jmp SendMotorByte                                      // EBC0

// Operation 10: operand selects headlamp on/off state.
CheckMotorHeadlamp:
    dex                                                    // EBC3
    bne L_EBD3                                             // EBC4
    lda ZP_OPERAND                                         // EBC6
    bne SetHeadlampOn                                      // EBC8

// Clear headlamp state $71; actual output is applied by IRQ headlamp service.
SetHeadlampOff:
    lda #$00                                               // EBCA
    bpl L_EBD0                                             // EBCC

// Set headlamp state $71=$40.
SetHeadlampOn:
    lda #$40                                               // EBCE

L_EBD0:
    sta ZP_HEADLAMP_STATE                                  // EBD0
    rts                                                    // EBD2

L_EBD3:
    dex                                                    // EBD3
    bne UpdateSelectedPosition                             // EBD4
    and #$0c                                               // EBD6
    ora ZP_MOTOR_STATUS                                    // EBD8
    bne L_EB82                                             // EBDA

// Homing sequence: 60,62; wait; 70,61; wait; initialize counters; C0/C1 handshake.
HomeRobot:
    lda #$40                                               // EBDC
    sta ZP_MOTOR_DIRECTION                                 // EBDE
    jsr SetHeadlampOff                                     // EBE0
    lda #$60                                               // EBE3
    jsr SendMotorByte                                      // EBE5
    lda #$62                                               // EBE8
    jsr SendMotorByte                                      // EBEA
    jsr WaitForMotorCompletion                             // EBED
    lda #$70                                               // EBF0
    jsr SendMotorByte                                      // EBF2
    lda #$61                                               // EBF5
    jsr SendMotorByte                                      // EBF7
    jsr WaitForMotorCompletion                             // EBFA
    lda #$00                                               // EBFD
    sta ZP_WHEEL_POSITION                                  // EBFF
    sta ZP_ARM_POSITION                                    // EC01
    sta ZP_CLAW_POSITION                                   // EC03
    sta ZP_MOTOR_AUX                                       // EC05
    sta ZP_WHEEL_SAVED_COUNT                               // EC07
    sta ZP_WRIST_SAVED_COUNT                               // EC09
    sta ZP_ARM_SAVED_COUNT                                 // EC0B
    sta ZP_CLAW_SAVED_COUNT                                // EC0D
    lda #$ff                                               // EC0F
    sta ZP_WRIST_POSITION                                  // EC11
    jsr MotorSettlingDelay                                 // EC13
    lda #$c0                                               // EC16
    jsr SendMotorByte                                      // EC18

// Return when $1000 bit 7 is high; otherwise send $C1 and retry.
WaitMotorHandshakeHigh:
    bit.abs IO_SERIAL_STATUS_HEADLAMP                      // EC1B
    bpl L_EC21                                             // EC1E
    rts                                                    // EC20

L_EC21:
    lda #$c1                                               // EC21
    jsr SendMotorByte                                      // EC23
    jmp WaitMotorHandshakeHigh                             // EC26

// Dispatch by X to a counter read and direction-dependent position update.
UpdateSelectedPosition:
    dex                                                    // EC29
    dex                                                    // EC2A
    dex                                                    // EC2B
    dex                                                    // EC2C
    dex                                                    // EC2D
    bne L_EC51                                             // EC2E
    jsr UndoWheelCount                                     // EC30
    lda #$84                                               // EC33

// A is supplied request (84 ordinary / 44 completion); apply count to wheel position.
ReadApplyWheelCounter:
    jsr ReadMotorReply                                     // EC35
    sta ZP_WHEEL_SAVED_COUNT                               // EC38
    sta ZP_TEMP_VALUE                                      // EC3A
    lda ZP_MOTOR_DIRECTION                                 // EC3C
    lsr                                                    // EC3E
    bcc L_EC49                                             // EC3F
    sec                                                    // EC41
    lda ZP_WHEEL_POSITION                                  // EC42
    sbc ZP_TEMP_VALUE                                      // EC44
    sta ZP_WHEEL_POSITION                                  // EC46
    rts                                                    // EC48

L_EC49:
    clc                                                    // EC49
    lda ZP_WHEEL_POSITION                                  // EC4A
    adc ZP_TEMP_VALUE                                      // EC4C
    sta ZP_WHEEL_POSITION                                  // EC4E
    rts                                                    // EC50

L_EC51:
    dex                                                    // EC51
    bne L_EC76                                             // EC52
    jsr UndoWristCount                                     // EC54
    lda #$82                                               // EC57

// A is supplied request (82 / 42); update wrist position and saved count.
ReadApplyWristCounter:
    jsr ReadMotorReply                                     // EC59
    sta ZP_WRIST_SAVED_COUNT                               // EC5C
    sta ZP_TEMP_VALUE                                      // EC5E
    lda ZP_MOTOR_DIRECTION                                 // EC60
    and #$10                                               // EC62
    beq L_EC6E                                             // EC64
    sec                                                    // EC66
    lda ZP_WRIST_POSITION                                  // EC67
    sbc ZP_TEMP_VALUE                                      // EC69
    sta ZP_WRIST_POSITION                                  // EC6B
    rts                                                    // EC6D

L_EC6E:
    clc                                                    // EC6E
    lda ZP_WRIST_POSITION                                  // EC6F
    adc ZP_TEMP_VALUE                                      // EC71
    sta ZP_WRIST_POSITION                                  // EC73
    rts                                                    // EC75

L_EC76:
    dex                                                    // EC76
    bne L_EC99                                             // EC77
    jsr UndoArmCount                                       // EC79
    lda #$81                                               // EC7C

// A is supplied request (81 / 41); update arm position and saved count.
ReadApplyArmCounter:
    jsr ReadMotorReply                                     // EC7E
    sta ZP_ARM_SAVED_COUNT                                 // EC81
    sta ZP_TEMP_VALUE                                      // EC83
    bit ZP_MOTOR_DIRECTION                                 // EC85
    bvc L_EC91                                             // EC87
    sec                                                    // EC89
    lda ZP_ARM_POSITION                                    // EC8A
    sbc ZP_TEMP_VALUE                                      // EC8C
    sta ZP_ARM_POSITION                                    // EC8E
    rts                                                    // EC90

L_EC91:
    clc                                                    // EC91
    lda ZP_ARM_POSITION                                    // EC92
    adc ZP_TEMP_VALUE                                      // EC94
    sta ZP_ARM_POSITION                                    // EC96
    rts                                                    // EC98

L_EC99:
    dex                                                    // EC99
    bne L_ECC4                                             // EC9A
    jsr UndoClawCount                                      // EC9C
    lda #$80                                               // EC9F

// A is supplied request (80 / 40); reduce count and position modulo $55 (85).
ReadApplyClawCounter:
    jsr ReadMotorReply                                     // ECA1

L_ECA4:
    cmp #$55                                               // ECA4
    bcc L_ECAE                                             // ECA6
    sec                                                    // ECA8
    sbc #$55                                               // ECA9
    jmp L_ECA4                                             // ECAB

L_ECAE:
    sta ZP_TEMP_VALUE                                      // ECAE
    sta ZP_CLAW_SAVED_COUNT                                // ECB0
    clc                                                    // ECB2
    adc ZP_CLAW_POSITION                                   // ECB3
    cmp #$55                                               // ECB5
    bcc L_ECBC                                             // ECB7
    sec                                                    // ECB9
    sbc #$55                                               // ECBA

L_ECBC:
    sta ZP_CLAW_POSITION                                   // ECBC
    rts                                                    // ECBE

// Set operation-status bit 7 and return.
RejectMotorOperation:
    asl ZP_MOTION_RESULT                                   // ECBF
    sec                                                    // ECC1
    ror ZP_MOTION_RESULT                                   // ECC2

L_ECC4:
    rts                                                    // ECC4

// Undo prior contribution, read completion counter 44, then clear saved counters.
FinalizeWheelPosition:
    jsr UndoWheelCount                                     // ECC5
    lda #$44                                               // ECC8
    jsr ReadApplyWheelCounter                              // ECCA
    lda #$00                                               // ECCD
    sta ZP_WHEEL_SAVED_COUNT                               // ECCF
    sta ZP_WHEEL_LAST_COUNT                                // ECD1
    rts                                                    // ECD3

// Completion-counter path for wrist, request 42.
FinalizeWristPosition:
    jsr UndoWristCount                                     // ECD4
    lda #$42                                               // ECD7
    jsr ReadApplyWristCounter                              // ECD9
    lda #$00                                               // ECDC
    sta ZP_WRIST_SAVED_COUNT                               // ECDE
    sta ZP_WRIST_LAST_COUNT                                // ECE0
    rts                                                    // ECE2

// Completion-counter path for arm, request 41.
FinalizeArmPosition:
    jsr UndoArmCount                                       // ECE3
    lda #$41                                               // ECE6
    jsr ReadApplyArmCounter                                // ECE8
    lda #$00                                               // ECEB
    sta ZP_ARM_SAVED_COUNT                                 // ECED
    sta ZP_ARM_LAST_COUNT                                  // ECEF
    rts                                                    // ECF1

// Completion-counter path for claw, request 40.
FinalizeClawPosition:
    jsr UndoClawCount                                      // ECF2
    lda #$40                                               // ECF5
    jsr ReadApplyClawCounter                               // ECF7
    lda #$00                                               // ECFA
    sta ZP_CLAW_SAVED_COUNT                                // ECFC
    sta ZP_CLAW_LAST_COUNT                                 // ECFE
    rts                                                    // ED00

// Undo the previous counter contribution using saved wheel direction.
UndoWheelCount:
    lda ZP_MOTOR_DIRECTION                                 // ED01
    lsr                                                    // ED03
    bcs L_ED0E                                             // ED04
    sec                                                    // ED06
    lda ZP_WHEEL_POSITION                                  // ED07
    sbc ZP_WHEEL_SAVED_COUNT                               // ED09
    jmp L_ED13                                             // ED0B

L_ED0E:
    clc                                                    // ED0E
    lda ZP_WHEEL_POSITION                                  // ED0F
    adc ZP_WHEEL_SAVED_COUNT                               // ED11

L_ED13:
    sta ZP_WHEEL_POSITION                                  // ED13
    rts                                                    // ED15

// Undo prior wrist count using direction bit 4.
UndoWristCount:
    lda ZP_MOTOR_DIRECTION                                 // ED16
    and #$10                                               // ED18
    bne L_ED24                                             // ED1A
    sec                                                    // ED1C
    lda ZP_WRIST_POSITION                                  // ED1D
    sbc ZP_WRIST_SAVED_COUNT                               // ED1F
    jmp L_ED29                                             // ED21

L_ED24:
    clc                                                    // ED24
    lda ZP_WRIST_POSITION                                  // ED25
    adc ZP_WRIST_SAVED_COUNT                               // ED27

L_ED29:
    sta ZP_WRIST_POSITION                                  // ED29
    rts                                                    // ED2B

// Undo prior arm count using direction bit 6.
UndoArmCount:
    bit ZP_MOTOR_DIRECTION                                 // ED2C
    bvs L_ED38                                             // ED2E
    sec                                                    // ED30
    lda ZP_ARM_POSITION                                    // ED31
    sbc ZP_ARM_SAVED_COUNT                                 // ED33
    jmp L_ED3D                                             // ED35

L_ED38:
    clc                                                    // ED38
    lda ZP_ARM_POSITION                                    // ED39
    adc ZP_ARM_SAVED_COUNT                                 // ED3B

L_ED3D:
    sta ZP_ARM_POSITION                                    // ED3D
    rts                                                    // ED3F

// Subtract prior claw count before replacing it.
UndoClawCount:
    sec                                                    // ED40
    lda ZP_CLAW_POSITION                                   // ED41
    sbc ZP_CLAW_SAVED_COUNT                                // ED43
    sta ZP_CLAW_POSITION                                   // ED45
    rts                                                    // ED47
.assert "20_motors end", *, $0ed48
