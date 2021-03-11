nse_execDPCM:
    rts

nse_execSq_SetVolume:
    ; preconditions:
    ;   X = channel idx + 1
    ;   GV2 lower nibble = volume amount
    lda wNSE_genVar2
    and #$0F
    sta wNSE_genVar2
    lda wMusChannel_BaseVolume-1.w, x
    and #$F0
    eor wNSE_genVar2
    sta wMusChannel_BaseVolume-1.w, x
    jmp nse_execChannelCommands

nse_execSq_SetEcho:
    ; TODO
    lda wChannelIdx_a1
    bne nse_execChannelCommands_A ; guaranteed jump

nse_execSq_SetEchoVolume:
    ; preconditions:
    ;   X = channel idx + 1
    ;   GV2 lower nibble = echo volume amount
    lda wNSE_genVar2
    shift 4
    sta wNSE_genVar2
    lda wMusChannel_BaseVolume-1.w, x
    and #$0F
    eor wNSE_genVar2
    sta wMusChannel_BaseVolume-1.w, x
    
    ; fallthrough nse_execChannelCommands

; preconditions:
;    wChannelIdx_a1 = channel idx + 1
;    x = channel index + 1
nse_execChannelCommands:
    txa
    ; fallthrough nse_execChannelCommands_A

; preconditions: 
;    wChannelIdx_a1 = channel idx + 1
;    A = channel_idx + 1
nse_execChannelCommands_A:
    ; retrieve command byte for channel idx
    nse_nextMacroByte_inline ; OPTIMIZE: consider making this non-inlined?
    ; A is now the next command byte
    ; X is now 3*(channel_idx+1)

    cpx #(NSE_DPCM+1)*3
    beq nse_execDPCM
    bne nse_execSqTriNoise ; guaranteed jump

; preconditions:
;   A = command byte
;   wChannelIdx_a1 = channel_idx + 1
;   X = channel_idx + 1
nse_exec_Note:
    ; base pitch <- command byte
    sta wMusChannel_BasePitch-1.w, x

    ; detune accumulator <- 0
    lda #$0
    sta wMusChannel_DetuneAccumulator_Lo.w, x
    sta wMusChannel_DetuneAccumulator_Hi.w, x

    ; reset vibrato index
    ldy channelMacroVibratoTable-1.w, x
    sta wMacro_start+2,y ; (A = 0)

    jmp nse_exec_readInstrWait

; preconditions:
;   A = command byte
;   wChannelIdx_a1 = channel_idx + 1
nse_execSqTriNoise:
    ldx wChannelIdx_a1
    cmp #$4E
    bcc nse_exec_Note
    beq nse_exec_readVolWait
    ; (+C)
    sbc #$90
    bcs nse_exec_effect
    ; (-C)
    adc #$90-$50
    bpl nse_execSq_SetProperty
    ; fallthrough nse_exec_Release

nse_exec_Release:
    ; TODO
    rts

; preconditions:
;   GV2 lower nibble = amount to wait
;   X = channel_idx + 1
nse_exec_Cut:
    lda #$0
    sta wMusChannel_BaseVolume-1.w, x

    ; load wait amount
    lda wNSE_genVar2
    and #$0F
    bne nse_setWait ; guaranteed jump (amount to wait > 0)

; preconditions:
;   wChannelIdx_a1 = channel_idx + 1
;   X = channel_idx + 1
nse_exec_readVolWait:
    ; X <- channel_idx + 1
    ; A <- next phrase byte
    ; wNSE_genVar2 <- phrase byte
    txa
    jsr nse_nextMacroByte
    sta wNSE_genVar2
    ldx wChannelIdx_a1

    ; volume[channel_idx] <- (high nibble)
    shift -4
    sta wMusChannel_BaseVolume-1.w, x
    ; fallthrough

; preconditions:
;   X = channel_idx + 1
nse_execSetWaitFromLowNibbleGV2:
    lda wNSE_genVar2
    and #$0F
    ; fallthrough

; preconditions:
;   A = number of rows to wait
;   X = channel_idx + 1
nse_setWait:
    ; convert to _a1
    clc
    adc #$1
    sta wMusChannel_RowsToNextCommand_a1-1.w, x
    rts

; preconditions:
; A = (command - $90)
; command >= 90
nse_exec_effect:
; special case: if command == $ff, it's actually note A-0.
    cmp #$ff-$90
    bne +
    lda #$0 ; $FF is an alias for 0 because macros cannot contain 0.
    jmp nse_exec_Note
; -----------------
; actual effects:
+   asl
    tay
    jsr jumpTableNoPreserveY
@nse_exec_effect_jumpTable:
    .dw nse_exec_effect_channelBaseDetune ; $90
    .dw nse_exec_effect_channelArpXY ; $91
    .dw nse_exec_effect_vibrato ; $92
    .dw nse_exec_effect_hardwareSweepUp ; $93
    .dw nse_exec_effect_hardwareSweepDown ; $94
    .dw nse_exec_effect_lengthCounter ; $95
    .dw nse_exec_effect_linearCounter ; $96
    .dw nse_exec_effect_portamento ; $97
    .dw nse_exec_effect_hardwareSweepDisable ; $98

nse_execSq_SetProperty:
    ; precondition: X = channel idx + 1
    ; store the command so we can access its lower nibble later.
    sta wNSE_genVar2

    ; Y <- 2*(high nibble of command)
    and #$F0
    lsr
    lsr
    lsr
    tay
    
    jsr jumpTableNoPreserveY
@nse_execSqSetProperty_JumpTable:
    .dw nse_exec_Cut ; $50-$5F
    .dw nse_execSq_SetEcho ; $60-$6F
    .dw nse_execSq_SetVolume ; $70-$7F
    .dw nse_execSq_SetEchoVolume ; $80-$8F

    nse_exec_effect_channelBaseDetune:
        ; precondition: X = channel idx + 1

        ; A <- next phrase byte
        txa
        jsr nse_nextMacroByte
        ldx wChannelIdx_a1
        sta wMusChannel_BaseDetune-1.w, x
        jmp nse_execChannelCommands ; do next command

    nse_exec_effect_channelArpXY:
        ; precondition: X = channel idx + 1

        ; disable portamento on this channel
        ; (this is a documented side-effect)
        lda #$FF
        eor bitIndexTable-1.w, x
        and wMusChannel_Portamento.w
        sta wMusChannel_Portamento.w

        ; A <- next phrase byte
        txa
        jsr nse_nextMacroByte
        ldx wChannelIdx_a1
        sta wMusChannel_ArpXY-1.w, x
        jmp nse_execChannelCommands ; do next command

    nse_exec_effect_portamento:

        ; set portamento flag for channel
        lda bitIndexTable-1.w, x
        ora wMusChannel_Portamento.w
        sta wMusChannel_Portamento.w

        ; GV1 <- offset of portamento base struct for channel
        lda channelMacroPortamentoAddrTable.w, x
        sta wNSE_genVar4

        ; GV2 <- 
        lda wMusChannel_BasePitch.w, x
        sta wNSE_genVar3

        ; GV0 <- next phrase byte (portamento rate)
        txa 
        jsr nse_nextMacroByte
        sta wNSE_genVar0

        ; set portamento stored frequency from channel's base pitch

        ; Y <- offset of portamento struct (stored/co-opted in macro dataspace)
        ldy wNSE_genVar3

        ; X <- base pitch
        ldx wNSE_genVar4

        lda pitchFrequencies_lo.w, x
        sta wMacro_start, y
        lda pitchFrequencies_hi.w, x
        sta wMacro_start+1, y
        lda wNSE_genVar0
        sta wMacro_start+2, y

        ; next command
        lda wChannelIdx_a1
        jmp nse_execChannelCommands_A

    nse_exec_effect_vibrato:
        ; TODO
        jmp nse_execChannelCommands

    nse_exec_effect_hardwareSweepUp:
        lda #$80
        bit_skip_2
        ; fallthrough (~BIT SKIP)
        
    nse_exec_effect_hardwareSweepDown:
        lda #$88
        sta wNSE_genVar0

        ; tempaddr1 <- sweep address
        lda _nse_hardwareTable_lo-1.w, x
        sta wSoundBankTempAddr1
        lda >SQ1_SWEEP ; note that SQ1 sweep hi = SQ2 sweep hi 
        sta wSoundBankTempAddr1+1

        ; A <- next phrase byte
        txa
        jsr nse_nextMacroByte

        ; set enable and possibly negate bits
        tay
        and #$77
        ora wNSE_genVar0

        ; hardware sweep register <- A
        ldy #$1
        sta (wSoundBankTempAddr1), y
        jmp nse_execChannelCommands

    nse_exec_effect_hardwareSweepDisable:
        ; precondition: X = channel idx + 1

        lda _nse_hardwareTable_lo-1.w, x
        sta wSoundBankTempAddr2
        lda >SQ1_SWEEP ; note that SQ1 sweep hi = SQ2 sweep hi 
        sta wSoundBankTempAddr2+1

        ; note: A = $40, which is >SQ1_SWEEP
        ; (this value also happens to disable the sweep.)
        ldy #$1
        sta (wSoundBankTempAddr2), y
        jmp nse_execChannelCommands

    nse_exec_effect_lengthCounter:
    nse_exec_effect_linearCounter:
        ; TODO
        rts
    
nse_exec_readInstrWait:
    ; preconditions:
    ;   X = channel idx + 1
    txa ; A <- channel idx + 1
    nse_nextMacroByte_inline ; A <- next phrase byte
    ; wNSE_genVar1 = channel_idx+1
    sta wNSE_genVar2 ; wNSE_genVar2 <- phrase byte

@setInstr:
    ; Y <- 2 * high nibble (i.e., 2 * new instrument)
    and #$F0
    ; OPTIMIZE: compare with cached instrument value?
    shift -3
    tay
    
    ; X <- 2*(channel_idx + 1)
    asl wNSE_genVar1
    ldx wNSE_genVar1

    ; wSoundBankTempAddr2 <- wMusChannel_InstrTableAddr[channel_idx]
    lda wMusChannel_InstrTableAddr-2.w, X
    sta wSoundBankTempAddr2
    lda wMusChannel_InstrTableAddr-3.w, X
    sta wSoundBankTempAddr2+1
    
    ; wSoundBankTempAddr1 <- wInstrAddr[high nibble]
    lda (wSoundBankTempAddr2), Y
    sta wSoundBankTempAddr1
    iny
    lda (wSoundBankTempAddr2), Y
    sta wSoundBankTempAddr1+1

    ; X <- (channel base - wMacroStart)
    ; wNSE_genVar1 <- (channel end - wMacroStart)
    ; Y <- 0
    ldy wChannelIdx_a1
    lda channelMacroEndAddrTable-1.w, y
    sta wNSE_genVar1
    ldx channelMacroBaseAddrTable-1.w, y
    ldy #$0

    ; initialize macros to instrument defaults
    ; loop(channel macro data)
-   ; (macro.lo <- instrTable[y++]
    lda (wSoundBankTempAddr1), Y
    iny
    sta wMacro_start.w, x
    inx

    ; (macro.hi <- instrTable[y++]
    lda (wSoundBankTempAddr1), Y
    iny
    sta wMacro_start.w, x
    inx

    ; macro.offset <- 0
    lda #$0
    sta wMacro_start.w, x
    inx

    cpx wNSE_genVar1
    bmi -
    ; (end of loop)

    ; clear nibble parity flag
    ldx wChannelIdx_a1
    lda #$FF
    eor bitIndexTable-1.w, x
    and wMusChannel_ReadNibble.w
    sta wMusChannel_ReadNibble.w
    
@setWait:
    ; assumes x = channel idx + 1
    jmp nse_execSetWaitFromLowNibbleGV2