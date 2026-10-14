// Reconstructed stock Maxx Steele main ROM. KickAssembler 5.25 syntax.
// Source bytes: SHA-256 d6359ba53a5072ecf2e8703cecda8c63bb9a47c8f39cd07dd047089b2f2c1746
// Layout is intentionally locked for a byte-identical baseline; no optimization/removal.
.encoding "ascii"
#import "symbols.asm"
* = $e000 "Main ROM"
ROMStart:

#import "includes/00_boot.asm"
#import "includes/10_modes_program.asm"
#import "includes/11_program_helpers.asm"
#import "includes/12_remote_ui.asm"
#import "includes/20_motors.asm"
#import "includes/21_cop_serial.asm"
#import "includes/22_service_power.asm"
#import "includes/30_music.asm"
#import "includes/40_speech.asm"
#import "includes/50_display.asm"
#import "includes/51_clock_settings.asm"
#import "includes/52_display_data.asm"
#import "includes/60_game_first.asm"
#import "includes/61_random.asm"
#import "includes/62_game_helpers.asm"
#import "includes/63_game_second.asm"
#import "includes/70_remote_rx.asm"
#import "includes/71_interrupts.asm"
#import "includes/72_tune_data.asm"
#import "includes/99_vectors.asm"

ROMEnd:
.assert "Complete ROM length", ROMEnd-ROMStart, $2000
// The common effect-setup path relies on these handlers sharing a high byte.
.assert "Effect handler page sweep", >MusicSweepEffectIRQ, >MusicDecayEffectIRQ
.assert "Effect handler page random", >MusicRandomEffectIRQ, >MusicDecayEffectIRQ
.assert "Effect handler page oscillating", >MusicOscillatingEffectIRQ, >MusicDecayEffectIRQ
.assert "User phrase page alignment", <USER_PHRASES, 0
.assert "User tune page alignment", <USER_TUNE, 0
