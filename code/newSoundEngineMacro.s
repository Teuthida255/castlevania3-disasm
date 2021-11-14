; all macro code clobbers wNSE_genVar1, wNSE_genVar2, and wSoundBankTempAddr2

; ~32 bytes

; A <- macro X/3; Y clobbered; X unaffected
; A must contain high byte of macro base address (i.e., wMacro_start+1.w, X)
; optional argument: store previous macro offset in the given address.
; carry clear
.macro nse_nextMacroByte_inline_precalc_abaseaddr
        .ifndef SKIP_SET_MACRO_ADDR
        sta wSoundBankTempAddr2+1
        .ifdef MACRO_BYTE_ABSOLUTE
            lda wMacro_start+MACRO_BYTE_ABSOLUTE.w
        .else
            lda wMacro_start.w, X
        .endif
        sta wSoundBankTempAddr2
        .endif
        .if NARGS == 1
            ; carry is used to indicate if we've
            ; already set the previous counter value.
            sec
        .endif
    @@@_macro_loop\@:
        ; Y <- counter++
        .ifdef MACRO_BYTE_ABSOLUTE
            ldy wMacro_start+MACRO_BYTE_ABSOLUTE+2.w
        .else
            lda wMacro_start+2.w, X
            tay
        .endif

        .if NARGS == 1
            bcc @@@_macro_skip_store_prev_count\@
            sty \1
        @@@_macro_skip_store_prev_count\@:
        .endif

        ; ^ (counter++)
        .ifdef MACRO_BYTE_ABSOLUTE
            inc wMacro_start+MACRO_BYTE_ABSOLUTE+2.w
        .else
            inc wMacro_start+2.w, X
        .endif

        ; A <- macro[Y]
        lda (wSoundBankTempAddr2), Y
        LUA_ASSERT A_OR_Y_NONZERO
        .ifndef MACRO_NO_LOOP
            ; if not zero, we're done.
            bne @@@_macro_end\@

            .if NARGS == 1
                ; carry is used to indicate if we've
                ; already set the previous counter value.
                clc
            .endif

            ; otherwise... (A == 0)
            .ifndef MACRO_LOOP_ZERO
                tay
                lda (wSoundBankTempAddr2), Y
                .ifdef MACRO_BYTE_ABSOLUTE
                    sta wMacro_start+MACRO_BYTE_ABSOLUTE+2.w
                .else
                    sta wMacro_start+2.w, X
                .endif
                LUA_ASSERT BNE
                bne @@@_macro_loop\@ ; guaranteed, since no macro loops to position 0.
            .else
                ; set macro counter to 0.
                .ifdef MACRO_BYTE_ABSOLUTE
                    sta wMacro_start+MACRO_BYTE_ABSOLUTE+2.w
                .else
                    sta wMacro_start+2.w, X
                .endif

                ; guaranteed (since A == 0)
                LUA_ASSERT BEQ
                beq @@@_macro_loop\@
                .undef MACRO_LOOP_ZERO
            .endif
        .else
            .undef MACRO_NO_LOOP
            
            .ifdef MACRO_TRAMPOLINE_SPACE
                ; jump past trampoline space
                jmp @@@_macro_end\@
            .endif
        .endif

    .ifdef MACRO_TRAMPOLINE_SPACE
        LUA_ASSERT FALSE
        MACRO_TRAMPOLINE_\@
        .undef MACRO_TRAMPOLINE_SPACE
    .endif

    .ifdef MACRO_BYTE_ABSOLUTE
        .undef MACRO_BYTE_ABSOLUTE
    .endif

    @@@_macro_end\@:
.endm

.macro nse_nextMacroByte_inline_precalc ; A <- macro X/3; Y clobbered; X unaffected
        .ifdef MACRO_BYTE_ABSOLUTE
            lda wMacro_start+MACRO_BYTE_ABSOLUTE+1.w
        .else
            lda wMacro_start+1.w, X
        .endif
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
        adc wNSE_genVar1 ; (-C)
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

; A <- *macro[A]++; X <- 3A; Y clobbered
; don't loop to start (permit zeroes)
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