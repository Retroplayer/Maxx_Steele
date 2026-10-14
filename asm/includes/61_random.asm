// Shared random-number helper: also called by music effects
// Original CPU range $fa0c-$fa1a.
.assert "61_random start", *, $fa0c

// Shared 16-bit shift state $A4/$A5. SEI then unconditional CLI: does not preserve caller interrupt mask.
// Shared helper: proximity to game code is not proof of exclusive game ownership.
NextRandom:
    lda ZP_RANDOM_HI                                       // FA0C
    eor ZP_RANDOM_LO                                       // FA0E
    eor #$ff                                               // FA10
    rol                                                    // FA12
    rol                                                    // FA13
    sei                                                    // FA14; protect random-state update briefly; CLI below is unconditional
    rol ZP_RANDOM_LO                                       // FA15
    rol ZP_RANDOM_HI                                       // FA17
    cli                                                    // FA19; does not preserve caller IRQ-disable state

L_FA1A:
    rts                                                    // FA1A
.assert "61_random end", *, $0fa1b
