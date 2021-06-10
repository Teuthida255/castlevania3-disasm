LUA_MARKER NSE_COMMANDS_BEGIN

.macro assert_not_noise
    lda wChannelIdx_a1
    cmp #NSE_NOISE+1
    fail_if beq
.endm

.macro assert_not_dpcm
    lda wChannelIdx_a1
    cmp #NSE_DPCM+1
    fail_if beq
.endm

.macro assert_nz
    fail_if beq
.endm

.macro assert_X_eq_wchannelidx
    cpx wChannelIdx_a1
    fail_if bne
.endm

.macro assert_A_eq_wchannelidx
    cmp wChannelIdx_a1
    fail_if bne
.endm

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
    ASSERT assert_A_eq_wchannelidx
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
    ; swap echo volume
    lda wMusChannel_BaseVolume-1.w, x
    swap_nibbles
    sta wMusChannel_BaseVolume-1.w, x
+
    ; detune accumulator <- 0
    lda #$0
    sta wMusChannel_DetuneAccumulator_Lo-1.w, x
    sta wMusChannel_DetuneAccumulator_Hi-1.w, x

    ; reset vibrato index

    ldy channelMacroVibratoTable-1.w, x
    beq + ; skip if this channel doesn't have vibrato
    sta wMacro_start+2,y ; (A = 0)
+
    jmp nse_exec_readInstrWait

; preconditions:
;   A = command byte
;   wChannelIdx_a1 = channel_idx + 1
nse_execSqTriNoise:
    ldx wChannelIdx_a1
    cmp #$9B
    bcc nse_exec_Note
    beq nse_exec_readVolWait ; ("tie")

    ; effects 9c-9f are invalid
    .macro _assertf_nse_9c_9f
        cmp #$A0
        fail_if bcc
    .endm
    ASSERT _assertf_nse_9c_9f

    ; (+C)
    sbc #$B0 
    bcs nse_exec_effect
    ; (-C)
    and #$0F
    beq nse_exec_slur
    ; fallthrough nse_exec_Cut
    ; A1..AF

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

    .macro _assertf_nse_effect_max
        ; assert command in range B0-BD
        cmp #$BD-$B0
        bcs @@@@fail
    .endm
    ASSERT _assertf_nse_effect_max

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

    ; check if portamento was enabled
    lda wMusChannel_portrate-1.w, x
    beq +

    ; disable portamento on this channel
    ; (this is a documented side-effect)
    lda #$0
    sta wMusChannel_portrate-1.w, x

    ; clear arp macro (it is invalid
    ; because the space was used for portamento data)
    lda channelMacroPortamentoAddrTable-1.w, x
    tax 
    lda #$0
    sta wMacro_start.w, x
    sta wMacro_start+1.w, x
    sta wMacro_start+2.w, x ; paranoia

    ; restore channel idx to X
    ldx wChannelIdx_a1
+
    ; A <- next phrase byte
    txa
    jsr nse_nextMacroByte_noloop
    ldx wChannelIdx_a1
    sta wMusChannel_ArpXY-1.w, x
    jmp nse_execChannelCommands ; do next command

nse_exec_effect_portamento:

    ; cancel arpxy (this is a documented side-effect)
    lda #$0
    sta wMusChannel_ArpXY-1.w, x

    ; GV4 <- offset of portamento base struct for channel
    lda channelMacroPortamentoAddrTable-1.w, x
    sta wNSE_genVar4

    ; GV3 <- base pitch
    lda wMusChannel_BasePitch-1.w, x
    sta wNSE_genVar3

    ; GV0 <- next phrase byte (portamento rate)
    txa 
    jsr nse_nextMacroByte_noloop
    ldx wChannelIdx_a1
    sta wMusChannel_portrate-1.w, x

    ; set portamento stored frequency from channel's base pitch

    ; Y <- offset of portamento struct (stored/co-opted in macro dataspace)
    ldy wNSE_genVar4

    ; X <- base pitch
    ldx wNSE_genVar3

    lda pitchFrequencies_lo.w, x
    sta wMacro_start, y
    lda pitchFrequencies_hi.w, x
    sta wMacro_start+1, y

    ; next command
    lda wChannelIdx_a1
    jmp nse_execChannelCommands_A

nse_exec_effect_vibrato:
    ASSERT assert_not_noise

    ; (X = channel idx + 1)
    txa
    jsr nse_nextMacroByte_noloop
    sta wNSE_genVar0
    lda wChannelIdx_a1

    jsr nse_nextMacroByte_noloop
    ldx wChannelIdx_a1

    ; vibrato hi <- second phrase byte
    ldy channelMacroVibratoTable-1.w, x
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
    ASSERT assert_not_noise
    ; set hi byte of vibrato address to 0
    ; (this indicates vibrato is disabled)
    lda #$0
    ldy channelMacroVibratoTable-1.w, x
    ASSERT assert_nz
    sta wMacro_start+1, y
    jmp nse_execChannelCommands

nse_exec_groove:
    ; (X = channel idx + 1)
    txa
    jsr nse_nextMacroByte_noloop
    sta wNSE_genVar0
    lda wChannelIdx_a1

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
    txa
    jsr nse_nextMacroByte_noloop
    ldx wChannelIdx_a1
    sta wMusChannel_BaseVolume-1.w, x
    jmp nse_execChannelCommands

nse_exec_skip_byte:
    ; precondition:
    ;   X = channel idx + 1
    txa
    jsr nse_nextMacroByte_noloop
    lda wChannelIdx_a1
    jmp nse_execChannelCommands_A

nse_exec_effect_hardwareSweep:
    ; skip this if sfx active (but read a byte anyway)
    lda bitIndexTable-1.w, x
    and wSFXChannelActive.w
    bne nse_exec_skip_byte

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

    ; next command
    lda wChannelIdx_a1
    jmp nse_execChannelCommands_A

nse_exec_effect_hardwareSweepDisable:
    ; precondition: X = channel idx + 1

    lda bitIndexTable-1.w, x
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
    lda bitIndexTable-1.w, x
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
    alr $F0
    ; OPTIMIZE: compare with cached instrument value?
    shift -2
@setInstrTAY: ; used by lua debugger
    tay

    ; if portamento enabled, we have to cache portamento value
    ldx wNSE_genVar1
    lda wMusChannel_portrate-1.w, x
    beq +
        lda channelMacroArpAddrTable-1.w, X
        tax
        lda wMacro_start.w, x
        pha
        lda wMacro_start+1.w, x
        pha
    +
        
    ; X <- 2*(channel_idx + 1)
    asl wNSE_genVar1
    ldx wNSE_genVar1

    ; wSoundBankTempAddr2 <- wMusChannel_CachedChannelTableAddr[channel_idx]
    lda wMusChannel_CachedChannelTableAddr-2.w, X
    sta wSoundBankTempAddr2
    lda wMusChannel_CachedChannelTableAddr-1.w, X
    sta wSoundBankTempAddr2+1

    .macro assert_instr_nonnull
        lda wSoundBankTempAddr2
        pass_if bne
        lda wSoundBankTempAddr2+1
        pass_if bne
        fail_by_default
    .endm
    ASSERT assert_instr_nonnull

    .macro assert_instr_nonzerotable
        ; instrument 0xF only is allowed to be null.
        cpy #(2*$F)
        pass_if beq
        lda wSoundBankTempAddr2
        cmp <nullTable
        pass_if bne
        lda wSoundBankTempAddr2+1
        cmp >nullTable
        pass_if bne
        fail_by_default
    .endm
    ASSERT assert_instr_nonzerotable
    
    ; wSoundBankTempAddr1 <- wInstrAddr[high nibble]
    ; (Y is 2 * instrument-idx)
    lda (wSoundBankTempAddr2), Y
    sta wSoundBankTempAddr1
    iny
    lda (wSoundBankTempAddr2), Y
    sta wSoundBankTempAddr1+1

    .macro assert_instr_nsebank
        ; instrument must be in range $8000-$9fff
        lda wSoundBankTempAddr1+1
        cmp #$A0
        fail_if bcs
        cmp #$80
        fail_if bcc
    .endm
    ASSERT assert_instr_nsebank

    ; X <- (channel base - wMacro_start)
    ; wNSE_genVar1 <- (channel end - wMacro_start)
    ; Y <- 0
@setInstr_SetMacros_InitLoop:
    ldy wChannelIdx_a1
    lda channelMacroEndAddrTable-1.w, y
    sta wNSE_genVar1
    ldx channelMacroBaseAddrTable-1.w, y
    ldy #$0

    ; initialize macros to instrument defaults
    ; loop(channel macro data)
@setInstr_SetMacros_LoopTop:
    ; (macro.lo <- instrTable[y++]
    lda (wSoundBankTempAddr1), Y
    sta wMacro_start.w, x
    iny
    inx

    ; (macro.hi <- instrTable[y++]
    lda (wSoundBankTempAddr1), Y
    beq @setInstr_SetMacros_MacroZero
    sta wMacro_start.w, x
    iny
    inx

    .macro assert_macro_nsebank_or_null
        ; macro address must either be in range $8000-$9fff or else null.

        ; null
        lda wMacro_start.w-1, x
        ora wMacro_start.w-2, x
        pass_if beq

        lda wMacro_start.w-1, x
        cmp #$A0
        fail_if bcs
        cmp #$80
        fail_if bcc
    .endm
    ASSERT assert_macro_nsebank_or_null

    ; macro.offset <- 1 (after loop index byte)
    ; however, we skip this if macro hi is not set,
    ; because sometimes extra info is stored in
    ; the macro offset byte when the macro is disabled
    lda #$1
    sta wMacro_start.w, x
    inx

@setInstr_SetMacros_LoopNext:
    cpx wNSE_genVar1
    bmi @setInstr_SetMacros_LoopTop
    ; (end of loop)

@setInstr_SetMacros_LoopEnd:
    ; restore portamento value if needed
    ldx wChannelIdx_a1
    lda wMusChannel_portrate-1.w, x
    beq +
        ldy channelMacroArpAddrTable-1.w, X
        pla
        sta wMacro_start+1.w, y
        pla
        sta wMacro_start.w, y
    +

    ; clear nibble parity flag
    lda #$FF
    eor bitIndexTable-1.w, x
    and wMusChannel_ReadNibble.w
    sta wMusChannel_ReadNibble.w
    
@setWait:
    ; assumes x = channel idx + 1
    jmp nse_execSetWaitFromLowNibbleGV2

@setInstr_SetMacros_MacroZero:
    iny
    inx
    inx
    bne @setInstr_SetMacros_LoopNext ; guaranteed

LUA_MARKER NSE_COMMANDS_END