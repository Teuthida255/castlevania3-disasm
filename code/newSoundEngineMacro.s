; all macro code clobbers wNSE_genVar1, wNSE_genVar2, and wSoundBankTempAddr2

; ~32 bytes

; A <- macro X/3; Y clobbered; X unaffected
; A must contain high byte of macro base address (i.e., wMacroStart+1.w, X)
; optional argument: store previous macro offset in the given address.
.macro nse_nextMacroByte_inline_precalc_abaseaddr
        sta wSoundBankTempAddr2+1
        lda wMacro_start.w, X
        sta wSoundBankTempAddr2
    @@@_macro_loop\@:
        lda wMacro_start+2.w, X
        .if NARGS == 1
            sta \1
        .endif
        inc wMacro_start+2.w, X
        tay
        lda (wSoundBankTempAddr2), Y
        .ifndef MACRO_NO_LOOP
            bne @@@_macro_end\@

            ; only if macro lookup fails
            ; A = 0
            .ifndef MACRO_LOOP_ZERO
                tay
                lda (wSoundBankTempAddr2), Y
                sta wMacro_start+2.w, X
                bne @@@_macro_loop\@ ; guaranteed, since no macro loops to position 0.
            .else
                sta wMacro_start+2.w, X
                beq @@@_macro_loop\@
                .undef MACRO_LOOP_ZERO
            .endif
        .else
            .undef MACRO_NO_LOOP
        .endif

    .ifdef MACRO_TRAMPOLINE_SPACE
        MACRO_TRAMPOLINE_\@
        .undef MACRO_TRAMPOLINE_SPACE
    .endif

    @@@_macro_end\@:
.endm

.macro nse_nextMacroByte_inline_precalc ; A <- macro X/3; Y clobbered; X unaffected
        lda wMacro_start+1.w, X
        beq @@@_macro_end_p\@ ; if macro address is 0, skip.
        .if NARGS == 1
            nse_nextMacroByte_inline_precalc_abaseaddr \1
        .else
            nse_nextMacroByte_inline_precalc_abaseaddr
        .endif
        @@@_macro_end_p\@:
.endm

.macro nse_nextMacroByte_inline ; A <- *macro[A]++; X <- 3A; Y clobbered
        sta wNSE_genVar1
        asl ; assumption: bit 7 in A was clear.
        adc wNSE_genVar1
        tax
        .if NARGS == 1
            nse_nextMacroByte_inline_precalc \1
        .else
            nse_nextMacroByte_inline_precalc
        .endif
.endm

; A <- *Song++; X <- 0; Y clobbered
nse_nextSongByte:
    ldx #$0
    stx wNSE_genVar1
    beq nse_nextMacroByte@precalc ; guaranteed branch

; A <- *macro[A]++; X <- 3A; Y clobbered
nse_nextMacroByte:
    sta wNSE_genVar1
    asl ; -C
    adc wNSE_genVar1
    tax
@precalc:
    lda wMacro_start+1.w, X
    beq @rts
@precalc_abaseaddr:
    nse_nextMacroByte_inline_precalc_abaseaddr
@rts:
    rts

nse_nextMacroByte_noloop:
    .define MACRO_NO_LOOP
    nse_nextMacroByte_inline
    rts


; A <- macro[A].offset; X <- 3A;
.macro nse_getMacroOffsetinline
    sta wNSE_genVar1
    asl ; -C
    adc wNSE_genVar1
    tax
    lda wMacro_start+2, x
.endm

; macro[A].offset <- Y; X <- 3A;
.macro nse_setMacroOffset_inline
    sta wNSE_genVar1
    asl ; -C
    adc wNSE_genVar1
    tax
    sty wMacro_start+2, x
.endm