// Hardware NMI, reset, and IRQ vectors
// Original CPU range $fffa-$ffff.
.assert "99_vectors start", *, $fffa

HardwareVectors:
    .word NMIEntry // FFFA; Hardware NMI vector.
    .word ResetEntry // FFFC; Hardware reset vector.
    .word IRQEntry // FFFE; Hardware IRQ/BRK vector.
.assert "99_vectors end", *, $10000
