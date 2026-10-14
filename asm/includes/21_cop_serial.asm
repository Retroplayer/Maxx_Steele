// Head/motor byte serializer and complemented motor replies
// Original CPU range $ed48-$edae.
.assert "21_cop_serial start", *, $ed48

// Send E3, then F3. Fall through into head-byte transmitter.
BeginHeadDisplayFrame:
    lda #$e3                                               // ED48
    jsr SendHeadByte                                       // ED4A
    lda #$f3                                               // ED4D

// A=byte; MSB first. Uses $5E/$5F/$60; head data phases are $1A/$1B.
SendHeadByte:
    sta ZP_SERIAL_SHIFT                                    // ED4F
    lda #$0d                                               // ED51
    bne SerialTransmitSetup                                // ED53

// A=byte; shares serializer, motor data phases $1C/$1D.
SendMotorByte:
    sta ZP_SERIAL_SHIFT                                    // ED55
    lda #$0e                                               // ED57

// Shared serializer. Poll timing bit 6, shift outgoing bit, restore idle $F8.
SerialTransmitSetup:
    sta ZP_SERIAL_CONTROL                                  // ED59
    lda #$08                                               // ED5B
    sta ZP_SERIAL_BITS                                     // ED5D

// Wait until BIT $1000 sets V (bit 6 high).
WaitSerialClockHigh:
    bit.abs IO_SERIAL_STATUS_HEADLAMP                      // ED5F
    bvc WaitSerialClockHigh                                // ED62
    lda ZP_SERIAL_CONTROL                                  // ED64
    rol ZP_SERIAL_SHIFT                                    // ED66
    rol                                                    // ED68
    sta.abs IO_COP_CONTROL_STATUS                          // ED69

// Wait until BIT $1000 clears V (bit 6 low).
WaitSerialClockLow:
    bit.abs IO_SERIAL_STATUS_HEADLAMP                      // ED6C
    bvs WaitSerialClockLow                                 // ED6F
    lda #$f8                                               // ED71
    sta.abs IO_COP_CONTROL_STATUS                          // ED73
    dec ZP_SERIAL_BITS                                     // ED76
    bne WaitSerialClockHigh                                // ED78
    rts                                                    // ED7A

// Send A request; receive eight MSB-first bits from $1000 bit 0, then complement result.
ReadMotorReply:
    jsr SendMotorByte                                      // ED7B
    lda #$08                                               // ED7E
    sta ZP_SERIAL_BITS                                     // ED80

// Receive-phase timing wait for bit 6 high.
WaitReplyClockHigh:
    bit.abs IO_SERIAL_STATUS_HEADLAMP                      // ED82
    bvc WaitReplyClockHigh                                 // ED85
    lda #$f4                                               // ED87
    sta.abs IO_COP_CONTROL_STATUS                          // ED89

// Receive-phase timing wait for bit 6 low.
WaitReplyClockLow:
    bit.abs IO_SERIAL_STATUS_HEADLAMP                      // ED8C
    bvs WaitReplyClockLow                                  // ED8F
    lda.abs IO_SERIAL_STATUS_HEADLAMP                      // ED91; sample serial reply bit 0; EOR $FF below inverts completed byte
    lsr                                                    // ED94
    rol ZP_SERIAL_SHIFT                                    // ED95
    lda #$f0                                               // ED97
    sta.abs IO_COP_CONTROL_STATUS                          // ED99
    dec ZP_SERIAL_BITS                                     // ED9C
    bne WaitReplyClockHigh                                 // ED9E

L_EDA0:
    bit.abs IO_SERIAL_STATUS_HEADLAMP                      // EDA0
    bvc L_EDA0                                             // EDA3
    lda #$f8                                               // EDA5
    sta.abs IO_COP_CONTROL_STATUS                          // EDA7
    lda ZP_SERIAL_SHIFT                                    // EDAA
    eor #$ff                                               // EDAC
    rts                                                    // EDAE
.assert "21_cop_serial end", *, $0edaf
