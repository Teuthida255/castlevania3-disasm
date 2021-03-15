nse_execDPCM:
    rts

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
    nse_nextMacroByte_inline
    ; A is now the next command byte
    ; X is now 3*(channel_idx+1)

    cpx #(NSE_DPCM+1)*3
    beq nse_execDPCM
    bne nse_execSqTriNoise ; guaranteed jump

; preconditions:
;   wChannelIdx_a1 = channel_idx + 1
;   X = channel_idx + 1
nse_exec_Note_A0:
    lda #$0
    ; fallthrough nse_exec_Note

; preconditions:
;   A = command byte
;   wChannelIdx_a1 = channel_idx + 1
;   X = channel_idx + 1
nse_exec_Note:
    ; shift "swap to echo volume" byte into carry
    lsr

    ; base pitch <- command byte
    sta wMusChannel_BasePitch-1.w, x

    bcc +
    ; swap echo volume if 
    lda wMusChannel_BaseVolume-1.w, x
    swap_nibbles
    sta wMusChannel_BaseVolume-1.w, x
+
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
    cmp #$9B
    bcc nse_exec_Note
    beq nse_exec_readVolWait ; ("tie")
    ; (+C)
    sbc #$B0 
    bcs nse_exec_effect
    ; (-C)
    and #$0F
    beq nse_exec_slur
    ; fallthrough nse_exec_Cut

; preconditions:
;   A = amount to wait, A != 0
;   X = channel_idx + 1
nse_exec_Cut:
    tay

    lda #$0
    sta wMusChannel_BaseVolume-1.w, x

    tya
    bne nse_setWait ; guaranteed jump (amount to wait > 0)

nse_exec_slur:
; preconditions:
;   X = channel_idx + 1

    ; A <- next phrase byte (pitch)
    txa
    jsr nse_nextMacroByte_noloop
    ldx wChannelIdx_a1

    ; base pitch <- A
    sta wMusChannel_BasePitch-1.w, x
    ; fallthrough nse_exec_readVolWait

; preconditions:
;   wChannelIdx_a1 = channel_idx + 1
;   X = channel_idx + 1
nse_exec_readVolWait:
    ; X <- channel_idx + 1
    ; A <- next phrase byte
    ; wNSE_genVar2 <- phrase byte
    txa
    jsr nse_nextMacroByte_noloop
    sta wNSE_genVar2
    ldx wChannelIdx_a1

    ; volume[channel_idx] <- (high nibble) (unless read volume is 0)
    shift -4
    beq +
        ; GV1 <- volume as low nibble
        sta wNSE_genVar1
        lda wMusChannel_BaseVolume-1.w, x
        and #$F0
        ora wNSE_genVar1
        sta wMusChannel_BaseVolume-1.w, x
    +
    ; fallthrough

; preconditions:
;   X = channel_idx + 1
nse_execSetWaitFromLowNibbleGV2:
    lda wNSE_genVar2
    and #$0F
    ; fallthrough nse_setWait

; preconditions:
;   A = number of rows to wait (1 = next row, 0 is invalid)
;   X = channel_idx + 1
nse_setWait:
    sta wMusChannel_RowsToNextCommand_a1-1.w, x
    rts

; preconditions:
;   A = (command - $B0)
;   command >= B0
;   wChannelIdx_a1 = channel_idx + 1
;   X = channel_idx + 1
nse_exec_effect:
    beq nse_exec_release ; optional: remove this
; -----------------
; actual effects:
    asl
    tay
    jsr jumpTableNoPreserveY
@nse_exec_effect_jumpTable:
    .dw nse_exec_release ; $B0
    .dw nse_exec_groove ; $B1
    .dw nse_exec_volume ; $B2
    .dw nse_exec_effect_channelBaseDetune ; $B3
    .dw nse_exec_effect_channelArpXY ; $B4
    .dw nse_exec_effect_vibrato ; $B5
    .dw nse_exec_effect_vibrato_cancel ; $B6
    .dw nse_exec_effect_hardwareSweep ; $B7
    .dw nse_exec_effect_hardwareSweepDisable ; $B8
    .dw nse_exec_effect_lengthCounter ; $B9
    .dw nse_exec_effect_linearCounter ; $BA
    .dw nse_exec_effect_portamento ; $BB
    .dw nse_exec_Note_A0 ; $BC

nse_exec_release:
    jmp nse_exec_readVolWait

nse_exec_effect_channelBaseDetune:
    ; precondition: X = channel idx + 1

    ; A <- next phrase byte
    txa
    jsr nse_nextMacroByte_noloop
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
    jsr nse_nextMacroByte_noloop
    ldx wChannelIdx_a1
    sta wMusChannel_ArpXY-1.w, x
    jmp nse_execChannelCommands ; do next command

nse_exec_effect_portamento:

    ; cancel arpxy (this is a documented side-effect)
    lda #$0
    sta wMusChannel_ArpXY.w, x

    ; set portamento flag for channel
    lda bitIndexTable.w, x
    ora wMusChannel_Portamento.w
    sta wMusChannel_Portamento.w

    ; GV1 <- offset of portamento base struct for channel
    lda channelMacroPortamentoAddrTable.w, x
    sta wNSE_genVar4

    ; GV
    lda wMusChannel_BasePitch.w, x
    sta wNSE_genVar3

    ; GV0 <- next phrase byte (portamento rate)
    txa 
    jsr nse_nextMacroByte_noloop
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
    ; (X = channel idx + 1)
    jsr nse_nextMacroByte_noloop
    sta wNSE_genVar0
    ldx wChannelIdx_a1

    jsr nse_nextMacroByte_noloop
    ldx wChannelIdx_a1

    ; vibrato hi <- second phrase byte
    ldy channelMacroVibratoTable.w, x
    sta wMacro_start+1, y

    ; vibrato lo <- first phrase byte
    lda wNSE_genVar0
    sta wMacro_start, y
    
    ; vibrato offset <- 0
    lda #$0
    sta wMacro_start+2, y

    ; next command
    jmp nse_execChannelCommands

nse_exec_effect_vibrato_cancel:
    ; set hi byte of vibrato address to 0
    ; (this indicates vibrato is disabled)
    lda #$0
    ldy channelMacroVibratoTable.w, x
    sta wMacro_start+1, y
    jmp nse_execChannelCommands

nse_exec_groove:
    ; (X = channel idx + 1)
    jsr nse_nextMacroByte_noloop
    sta wNSE_genVar0
    ldx wChannelIdx_a1

    jsr nse_nextMacroByte_noloop

    ; groove hi <- second phrase byte
    sta wMacro@Groove+1.w

    ; groove lo <- first phrase byte
    lda wNSE_genVar0
    sta wMacro@Groove.w
    
    ; groove offset <- 0
    lda #$0
    sta wMacro@Groove+2.w

    ; next command
    lda wChannelIdx_a1
    jmp nse_execChannelCommands_A

nse_exec_volume:
    jsr nse_nextMacroByte_noloop
    ldx wChannelIdx_a1
    sta wMusChannel_BaseVolume-1.w, x
    jmp nse_execChannelCommands

nse_exec_effect_hardwareSweep:
    lda bitIndexTable.w, x
    and wSFXChannelActive.w
    bne + ; skip this if sfx active

    ; tempaddr1 <- sweep address
    lda _nse_hardwareTable_lo-1.w, x
    sta wSoundBankTempAddr1
    lda >SQ1_SWEEP ; note that SQ1 sweep hi = SQ2 sweep hi 
    sta wSoundBankTempAddr1+1

    ; A <- next phrase byte
    txa
    jsr nse_nextMacroByte_noloop

    ; set enable bit
    tay
    ora #$80

    ; hardware sweep register <- A
    ldy #$1
    sta (wSoundBankTempAddr1), y
 +  jmp nse_execChannelCommands

nse_exec_effect_hardwareSweepDisable:
    ; precondition: X = channel idx + 1

    lda bitIndexTable.w, x
    and wSFXChannelActive.w
    bne + ; skip this if sfx active

    lda _nse_hardwareTable_lo-1.w, x
    sta wSoundBankTempAddr2
    lda >SQ1_SWEEP ; note that SQ1 sweep hi = SQ2 sweep hi 
    sta wSoundBankTempAddr2+1

    ; note: A = $40, which is >SQ1_SWEEP
    ; (this value also happens to disable the sweep.)
    ldy #$1
    sta (wSoundBankTempAddr2), y
 +  jmp nse_execChannelCommands

nse_exec_effect_lengthCounter:
nse_exec_effect_linearCounter:
    lda bitIndexTable.w, x
    and wSFXChannelActive.w
    bne + ; skip this if sfx active

    ; TODO

  + jmp nse_execChannelCommands
    
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

    ; X <- (channel base - wMacro_start)
    ; wNSE_genVar1 <- (channel end - wMacro_start)
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