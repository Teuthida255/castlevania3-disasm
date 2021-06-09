.macro autofail
    fail_if bpl
    fail_if bmi
.endm

.macro assert_only_hi_nibble
    and #$0F
    fail_if bne
.endm

.macro assert_30_mask
    and #$30
    cmp #$30
    fail_if bne
.endm

.macro assert_y_chan_idx
    cpy wChannelIdx
    fail_if bne
.endm

.macro assert_x_chan_idx
    cpx wChannelIdx
    fail_if bne
.endm

nse_musTickDPCM:
    rts

; input: wChannelIdx = channel
nse_musTick:
    ; dispatch depending on channel
    cpx #NSE_TRI
    beq nse_musTickTri
    cpx #NSE_DPCM
    beq nse_musTickDPCM
    ; noise and sq are same routine.
    jmp nse_musTickSq

.define nibbleParity wNSE_genVar6

nse_musTickTri_State:
    ; set up fast length macro access
    asl
    sta wSoundBankTempAddr2+1
    lda wMacro@Tri_Length.w
    sta wSoundBankTempAddr2

    ; GV0 <- loop point
    ldy #$0
    lda (wSoundBankTempAddr2), y
    sta wNSE_genVar0

    ; GV1 <- 0
    ; Y <- 1
    sty wNSE_genVar1
    iny

@loop_start:
    cpy wNSE_genVar0
    bne +

    ; Y = loop point
    lda wNSE_genVar1
    sta wNSE_genVar2
    
+   lda (wSoundBankTempAddr2), y
    bne +
    ; macro loop point
    lda wNSE_genVar2
    sta wMacro@Tri_Length+2.w
    ldy wNSE_genVar0
    lda (wSoundBankTempAddr2), y
    jmp @post_loop ; guaranteed -- loop point cannot be 0.
+   sta wNSE_genVar5
    and #$7F ; mask to bottom 7 bits
    sta wNSE_genVar4
    lda wNSE_genVar1
    clc ; subtract 1 more than gv4
    sbc wNSE_genVar4
    sta wNSE_genVar1
    bpl @loop_start ; ^ back to top of loop
@loop_aftermath:

    ; increment timer
    inc wMacro@Tri_Length+2.w

    ; load (un)mute value of final macro byte
    lda wNSE_genVar5
    ; loop end.

@post_loop:
    bpl nse_musTickTri@setUnmuted
    bmi nse_musTickTri@setMuted ; guaranteed

nse_musTickTri:
    ; update parity
    lda #$0
    sta nibbleParity
    lda wMusChannel_ReadNibble.w
    eor #(1 << NSE_TRI)
    sta wMusChannel_ReadNibble.w
    and #(1 << NSE_TRI)
    bne +
    inc nibbleParity
+    

    asl wMusTri_Prev.w ; bit 7 <- bit 6
    ; if volume is 0, skip right over the length/state macro stuff.
    ; TODO: reconsider this.
    lda wMusChannel_BaseVolume+NSE_TRI.w
    and #$0F
    beq @setMuted

    ; if macro address is odd, this is a State macro; otherwise, Length.
    lda wMacro@Tri_Length+1.w
    beq @setUnmuted ; no state/length macro -- set unmuted
    lda wMacro@Tri_Length.w ; OPTIMIZE -- we are loading two bytes here, could just load one maybe and pack better?
    lsr
    bcs nse_musTickTri_State

@LengthMacro:
    ; read length "macro" -- actually just a single byte.
    asl
    sta wSoundBankTempAddr2+1
    lda wMacro@Tri_Length.w
    sta wSoundBankTempAddr2
    ldy #$0

    ; compare macro value against current offset
    lda (wSoundBankTempAddr2), Y
    beq @setUnmuted ; 0 means don't mute.

    cmp wMacro@Tri_Length+2.w ; compare "offset"
    bcs @setMuted

    inc wMacro@Tri_Length+2.w ; increment "offset"
    ; fallthrough

    ; push volume and possibly set mute pending
@setUnmuted:
    lda #%01000000
    sta wMusTri_Prev.w ; for next tick.

    lda #%11000000 ; volume
    bit_skip_2 ; skip next op

@setMuted:
    lda #%10000000 ; volume

@epilogue:
    ldy #NSE_TRI ; this is wChannelIdx
    LUA_ASSERT Y_IS_CHAN_IDX
    ; read arp and detune macros as normal.
    jmp nse_musTickSq@PHA_then_setFrequency

nse_musTickSq_volzero:
    ; update nibble parity
    ldy wChannelIdx
    lda bitIndexTable, y

    ; start condition: nibble is 0 on even frames.
    and wMusChannel_ReadNibble.w
    sta nibbleParity ; on even frames, nibbleParity is 0, otherwise nonzero

    ; toggle nibble parity for this channel
    lda bitIndexTable, y
    eor wMusChannel_ReadNibble.w
    sta wMusChannel_ReadNibble.w
    
    ; GV0 <- wMusChannel_BaseVolume
    lda wMusChannel_BaseVolume, y
    and #$0F ; mask out alt (echo) volume
    bpl nse_musTickSq@before_setDutyCycle

    ASSERT autofail

nse_musTickNoise:
nse_musTickSq:
    ; preconditions:
    ;    X = channel idx

    ; nibbleParity set to 0/nonzero later on.
    lda #$1
    sta nibbleParity

@setVolume:
    ; ------------------------------------------
    ; VOLUME
    ; 
    ; Channels: sq1, sq2, noise, sq3, sq4
    ;
    ; Volume macro contains two-nibble pairs.
    ; We read high or low nibble depending on wMusChannel_ReadNibble,
    ; (and toggle wMusChannel_ReadNibble's bit for this channel)
    ; (note: wMusChannel_ReadNibble is used for other macros as well, so we have
    ; to update it even if volume macro is null.)
    ;
    ; ------------------------------------------

    LUA_ASSERT X_IS_CHAN_IDX

    ; X, GV5 <- channel's volume macro offset from macro base +2
    lda channelMacroVolAddrTable_a2.w, x
    sta wNSE_genVar5; store &[volume macro] in gv5 so duty cycle can reuse this later
    tax

    ; GV0 <- macro offset / counter
    lda wMacro_start.w, x
    sta wNSE_genVar0

    ; if volume macro is null (hi addr == 00) then `goto nse_musTickSq_volzero`
    lda wMacro_start-1.w, x
    beq nse_musTickSq_volzero ; special handling for instruments without volume macro.

    ; GV1 <- next volume macro byte
    dex
    dex
    nse_nextMacroByte_inline_precalc_abaseaddr
    sta wNSE_genVar1 ; store macro volume multiplier
    inx
    inx

    ; restore previous macro offset if nibble is even:
    ; Y <- (1 << channel idx)
    ; branch if ((1 << wChannelIdx) & wMusChannel_ReadNibble != 0)
    ldy wChannelIdx
    lda bitIndexTable, y
    tay
    and wMusChannel_ReadNibble.w
    bne +

        sta nibbleParity ; on even frames, nibbleParity is 0.

        ; macro counter <- GV0
        ; (restore previous macro offset (on even frames))
        lda wNSE_genVar0 
        sta wMacro_start.w, x
        
        ; GV1 <<= 4
        ; shift to upper nibble if loading even macro
        lda wNSE_genVar1
        shift 4
        sta wNSE_genVar1

+   ; wMusChannel_ReadNibble ^= (1 << channel idx)
    tya
    eor wMusChannel_ReadNibble.w
    sta wMusChannel_ReadNibble.w

    ; crop out lower portion of macro's nibble
    ; GV0 &= $f0
    lda wNSE_genVar1
    and #$f0
    sta wNSE_genVar1

@multiplyMacroAndBaseVolume:
    ; load base volume, select base volume nibble.
    ; Y <- channel idx
    ; A <- base volume & $0f
    ldy wChannelIdx
    lda wMusChannel_BaseVolume, y
    and #$0f

    ; multiply tmp volume with base volume
    ; using a lookup table.
    eor wNSE_genVar1 ; ora, eor -- it doesn't matter
    tax
    lda volumeTable.w, x

@before_setDutyCycle:
    LUA_ASSERT Y_IS_CHAN_IDX
    ; NOISE ------------------------
    ; skip duty cycle for noise channel (just push volume)
    cpy #NSE_NOISE
    beq @PHA_and_ora0011_then_setFrequency
    ; NOISE end --------------------

    sta wNSE_genVar0 ; GV0 <- volume

@setDutyCycle:
    LUA_ASSERT Y_IS_CHAN_IDX

    ; X <- duty cycle macro offset - 1
    ; A <- duty cycle macro hi addr
    ldx wNSE_genVar5
    lda wMacro_start+2.w, x
    beq @@@dutycycle_zero

    ; X <- duty cycle macro offset
    inx

    .macro MACRO_TRAMPOLINE_6
        @@@dutycycle_zero:
            ; set duty cycle from macro offset byte,
            ; which is reused to store duty cycle instead.
            lda wMacro_start+3.w, x

            LUA_ASSERT Y_IS_CHAN_IDX
            ASSERT assert_only_hi_nibble

            ; add important register flags
            ora #%00110000

            ; don't overwrite volume
            and #%11110000
            jmp @endSetDutyCycle
    .endm
    .define MACRO_TRAMPOLINE_SPACE

    ; A <- duty cycle macro value, wNSE_genVar7 <- previous duty cycle offset value
    nse_nextMacroByte_inline_precalc_abaseaddr wNSE_genVar7
    ldy wChannelIdx ; restore Y after above macro call
    ldx nibbleParity
    bne +
        ; even frame -- restore previous macro offset and shift up nibble.
        shift 4
        lda wNSE_genVar7
        ldx wNSE_genVar5
        sta wMacro_start+3.w, x
    + ; TODO: 4x-packed duty cycle values?
    ; assumption: macro bytes 4 and 5 are 1.
    and #$F0
@endSetDutyCycle:
    ora wNSE_genVar0 ; OR with volume

    LUA_ASSERT Y_IS_CHAN_IDX

@PHA_and_ora0011_then_setFrequency:
    ; enable certain important bits in volume channel (for noise and square)

    ;ASSERT assert_30_mask

    ; OPTIMIZE: avoid the need for this (assert_30_mask must never fail)
    ora #%00110000

@PHA_then_setFrequency:
    pha ; store volume for later.

@setFrequency:
    ; ------------------------------------------
    ; frequency
    ; ------------------------------------------
    ; get arpeggio (pitch offset)
    ; precondition: y = channel idx

    LUA_ASSERT Y_IS_CHAN_IDX

    ; x <- offset of arp address
    ldx channelMacroArpAddrTable.w, y
    stx wNSE_genVar5 ; store offset for arp macro table

    ; check if portamento enabled -- if so, do that instead of arpeggio
    ; (arpeggio and portamento are mutually exclusive)
    lda wMusChannel_portrate.w, y
    beq +
    jmp @doPortamento
+

    ; A <- next arpeggio macro value
    lda wMacro_start+1.w, x ; skip if macro is zero.
    LUA_ASSERT A0
    beq +

    ; if address is odd, this is a Fixed macro, not Arpeggio macro.
    lsr
    bcs @fixedMacro
    rol
    nse_nextMacroByte_inline_precalc_abaseaddr

  + sta wNSE_genVar1 ; store result
    and #%00111111   ; crop out ArpXY values
    .define arpValue wNSE_genVar0
    sta arpValue

    ; apply ArpXY to arpeggio offset
@ArpXYAdjust:
    bit wNSE_genVar1 ; N <- ArpX, V <- ArpY
    bvs @ArpY_UnkX ; br. ArpY
    bpl @ArpNegative ; br. ~ArpX
@ArpX:
    lda wMusChannel_ArpXY, y
    and #$0f ; get just the X nibble
    clc
    adc arpValue
    bcc @endArpXYAdjust ; guaranteed -- arpValue is the sum of two nibbles, so it cannot exceed $ff.

; --------------
; fixed macro (~sneak this in in the middle of arpeggio, why not!~)
; -------------
@fixedMacro:
    rol
    nse_nextMacroByte_inline_precalc_abaseaddr
    bpl + ; assumption: the only possible negative value is FF.
    ; FF means use unmodified base pitch, so this hack does that.
    sta arpValue
    sec
    bcs @endArpXYAdjust ; guaranteed

+   tax
    dex
    bpl @lookupFrequencyX ; guaranteed (pitches >= 0)

@ArpY_UnkX:
    bmi @endArpXYAdjustCLC
@ArpY:
    lda wMusChannel_ArpXY, y
    shift -4
    clc
    adc arpValue
    bcc @endArpXYAdjust ; guaranteed -- as above.

; (let's just slide a trampoline into this space...)
@NoiseArpEpilogue_tramp:
    jmp @NoiseArpEpilogue

@ArpNegative:
    ; negative arp value.
    sec
    lda #$00
    sbc arpValue

@endArpXYAdjustCLC:
    clc
@endArpXYAdjust:
    ; assumption: (-C)
    ; Y = channel idx
    ; set frequency lo
    lda wMusChannel_BasePitch.w, y
    adc arpValue

    ; NOISE ------------------------
    ; skip detune if noise channel
    cpy #NSE_NOISE
    beq @NoiseArpEpilogue_tramp
    clc
    ; NOISE end --------------------

    tax
@lookupFrequencyX:
    lda pitchFrequencies_lo.w, x
    sta wSoundFrequency
    lda pitchFrequencies_hi.w, x
    sta wSoundFrequency+1

@donePortamento:
@detune:
    ; detune
    clc
    ; X <- macro table offset for detune
    lda #$3
    adc wNSE_genVar5 ; macro table offset for Arp
    tax
    lda wMacro_start+2.w, x
    sta wNSE_genVar0 ; store previous macro idx for later

    ; A <- next detune value
    lda wMacro_start.w+1, x ; skip if macro is zero.
    beq @@@noDetune
    
    .macro MACRO_TRAMPOLINE_9
        ; this is used when no detune macro is specified
        @@@noDetune:
            ; everything that remains in this update can be skipped if sfx has priority.
            lda wNSE_current_channel_is_masked
            bne @detune@@maskedEarlyOut
            
            ldx wChannelIdx
            lda #$80
            clc
            bne @_adcFrequencyLo ; guaranteed

        @@@maskedEarlyOut:
            ; this is called when the tick routine exits partway through
            ; due to the sfx having priority.

            pla ; pop volume

            ; TODO -- continue vibrato even when masked?
            ; (requires zero-loop)
            
            ; (A ignored)
        
        @@@rts:
            rts
    .endm

    .define MACRO_TRAMPOLINE_SPACE
    nse_nextMacroByte_inline_precalc_abaseaddr

    ; odd/even detune macro value
    ldy nibbleParity
    bne +
    ; even frame -- shift nibble down
    shift -4
    tay
    
    ; restore previous macro offset
    lda wNSE_genVar0
    sta wMacro_start+2.w, x

    tya ; A <- high nibble (shifted to low nibble)
+   and #$0f

@accumulateDetune:
    ; add fine detune to persistent detune-accumulator (stored between ticks)
    ldx wChannelIdx
    ldy #$0
    
    ; convert from 4-bit reverse-signed value to 8-bit reverse-signed value
    clc
    sbc #$8
    tay
    lda #$0
    adc #$FF
    sta wNSE_genVar0 ; sign byte

    ; add to persistent detune value
    tya
    clc
    adc wMusChannel_DetuneAccumulator_Lo.w, x
    sta wMusChannel_DetuneAccumulator_Lo.w, x
    lda wNSE_genVar0 ; sign byte
    adc wMusChannel_DetuneAccumulator_Hi.w, x ; (-C)
    sta wMusChannel_DetuneAccumulator_Hi.w, x

@sumDetune:
    ; everything that remains in this update can be skipped if sfx has priority.
    lda wNSE_current_channel_is_masked
    bne @detune@@maskedEarlyOut

    ; wSoundBankTempAddr2 is macro base address; 3 bytes before it is the base detune offset.
    ; add base detune
    
    ; A <- <wSoundBankTempAddr2-3
    ; assumption: <wSoundBankTempAddr2 >= 3
    ; assumption (-C)
    lda wSoundBankTempAddr2
    adc #$FD ; -3
    sta wSoundBankTempAddr2
    clc
    lda (wSoundBankTempAddr2), y
@_adcFrequencyLo:
    ; (requires C-)
    adc wSoundFrequency.w
    sta wSoundFrequency.w
    bcs + ; instead of adding 1, just skip decrementing frequency hi.
@decrementFrequencyHi:
    ; we have to decrement frequency hi because we are adding two "reverse-signed"
    ; values (i.e. values where $80 represents zero) as though they were unsigned.
    dec wSoundFrequency.w+1
    clc
+

@addDetuneAccumulator:
    ; (-C)
    ; add detune-accumulator to current frequency
    lda wMusChannel_DetuneAccumulator_Lo.w, x
    adc wSoundFrequency.w
    sta wSoundFrequency.w
    lda wMusChannel_DetuneAccumulator_Hi.w, x
    adc wSoundFrequency+1.w
    sta wSoundFrequency+1.w
    clc

@addBaseDetune:
    ; (-C)
    ; channel base detune
    lda wMusChannel_BaseDetune.w, x
    adc wSoundFrequency.w
    sta wSoundFrequency.w
    bcc +
    inc wSoundFrequency.w+1
+   

@addVibrato:
    lda channelMacroVibratoTable.w, x
    tax

    clc
    lda wMacro_start+1.w, x
    beq @doneDetune

    ; A <- vibrato
    .define MACRO_LOOP_ZERO
    nse_nextMacroByte_inline_precalc_abaseaddr
    ; (-C)
    adc #$80
    bmi @negativeVibrato
    
    ; add vibrato
    clc
    adc wSoundFrequency
    sta wSoundFrequency
    bcc @doneDetune
    inc wSoundFrequency+1
    bne @doneDetune ; guaranteed

@negativeVibrato:
    sec
    sta wNSE_genVar0
    lda wSoundFrequency
    sbc wNSE_genVar0
    sta wSoundFrequency
    bcs +
    dec wSoundFrequency+1
    + clc

@doneDetune:
    ldx wChannelIdx

@writeRegisters:
    ; pre-requisites:
    ;   X = channel idx
    ;   (-C)

    ; Y <- cache register offset
    stx wNSE_genVar1
    txa
    asl
    adc wNSE_genVar1
    tay

    ; store volume in cached register
    pla ; A <- volume
    sta wMix_CacheReg_start, y
    
    ; store frequency in cached register
    lda wSoundFrequency
    sta wMix_CacheReg_start+1.w, y
    lda wSoundFrequency+1
    ; set length counter load to non-zero value
    ora #$80
    sta wMix_CacheReg_start+2.w, y
@writeRegistersRTS:
    rts

@NoiseArpEpilogue:
    ; precondition: A = absolute pitch (and junk in high nibble)

    ; early-out if sfx has priority
    ldx wNSE_current_channel_is_masked
    bne @pla_then_writeRegistersRTS

    ; gv0 <- absolute pitch modulo $F
    and #$F
    sta wNSE_genVar1

    ; arpValue bit 5 contains mode
    lda arpValue
    and %#00100000
    shift 2
    eor wNSE_genVar1

    ; set frequency
    sta wMix_CacheReg_Noise_Lo.w

    ; set volume and mode.
    pla
    ora #%00110000
    sta wMix_CacheReg_Noise_Vol.w
    bit_skip_1
@pla_then_writeRegistersRTS:
    pla
    rts

; --------------
; do portamento
; --------------
@doPortamento:
    ; calculate target frequency (simplified)
    ; preconditions:
    ;   Y = channel idx
    ;   A = portrate
    sta wNSE_genVar7 ; <- portrate

    ; X <- channel base pitch
    lda wMusChannel_BasePitch, y
    tax 

    ; Y <- portamento struct offset
    ; struct is 2 bytes stored frequency value, 1 byte speed
    lda channelMacroPortamentoAddrTable, Y
    tay

    ; compute target pitch - stored pitch
    ; then clamp to range [-portamento speed, +portamento speed]
    sec
    lda pitchFrequencies_lo.w, x
    sbc wMacro_start, y
    sta wSoundFrequency
    lda pitchFrequencies_hi.w, x
    sbc wMacro_start+1, y
    bmi @negativePortamento
@positivePortamento:
    bne @addPortamento
    lda wNSE_genVar7
    cmp wSoundFrequency
    bcs @completePortamento
@addPortamento:
    clc
    lda wNSE_genVar7
    adc wMacro_start, y
    sta wMacro_start, y
    sta wSoundFrequency
    lda #$0
    adc wMacro_start+1, y
    bpl @_completePortament_store_hi ; guaranteed (frequency hi <= 7)

@completePortamento:
    lda pitchFrequencies_lo.w, x
    sta wMacro_start, y
    sta wSoundFrequency
    lda pitchFrequencies_hi.w, x
@_completePortament_store_hi:
    sta wMacro_start+1, y
    sta wSoundFrequency+1
    jmp @donePortamento

@negativePortamento:
    cmp #$FF
    bne @subtractPortamento
    ; (-C)

    ; A <- negative portamento speed
    lda #$1
    sbc wNSE_genVar7

    ; ||speed|| < ||target - current||?
    cmp wSoundFrequency
    bcc @completePortamento
@subtractPortamento:
    lda wNSE_genVar7
    ; one's complement; must set carry to make this work.
    eor #$FF
    sec
    adc wMacro_start, y
    sta wMacro_start, y
    sta wSoundFrequency
    lda wMacro_start+1, y
    adc #$FF
    jmp @_completePortament_store_hi