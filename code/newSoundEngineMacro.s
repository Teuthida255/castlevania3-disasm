; all macro code clobbers wNSE_genVar1, wNSE_genVar2, and wSoundBankTempAddr2

; ~30 bytes
.macro nse_nextMacroByte_inline_precalc ; A <- macro X/3; Y clobbered
        lda wMacro.start, X
        sta wSoundBankTempAddr2
        lda wMacro.start+1, X
        sta wSoundBankTempAddr2+1
    _macro_loop\@:
        lda wMacro.start+2, X
        inc wMacro.start+2, X
        tay
        lda (wSoundBankTempAddr2), Y
        bne _macro_end\@

        ; only if macro lookup fails
        ; A = 0
        tay
        lda (wSoundBankTempAddr2), Y
        sta wMacro.start+2, X
        beq _macro_loop\@ ; guaranteed

    _macro_end\@:
.endm

.macro nse_nextMacroByte_inline ; A <- *macro[A]++; X <- 3A; Y clobbered
        sta wNSE_genVar1
        asl ; assumption: bit 7 in A was clear.
        adc wNSE_genVar1
        tax
        nse_nextMacroByte_inline_precalc
.endm

; A <- *Song++; X <- 0; Y clobbered
nse_nextSongByte:
    ldx #$0
    stx wNSE_genVar1
    beq nse_nextMacroByte@inline ; guaranteed branch

; A <- *macro[A]++; X <- 3A; Y clobbered
nse_nextMacroByte:
    sta wNSE_genVar1
    asl ; -C
    adc wNSE_genVar1
    tax
@inline:
    nse_getMacroByte_inline_precalc
    rts

; A <- macro[A].offset; X <- 3A;
.macro nse_getMacroOffsetinline
    sta wNSE_genVar1
    asl ; -C
    adc wNSE_genVar1
    tax
    lda wMacro.start+2, x
.endm

; macro[A].offset <- Y; X <- 3A;
.macro nse_setMacroOffset_inline
    sta wNSE_genVar1
    asl ; -C
    adc wNSE_genVar1
    tax
    sty wMacro.start+2, x
.endm