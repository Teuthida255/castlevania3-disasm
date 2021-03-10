.include "code/newSoundEngineMacro.s"

; Channels - SQ 1/2, TRI, NOISE, DPCM, MMC5 PULSE 1/2
nse_initSound:
    jsr nse_silenceAllSoundChannels

    lda #$7f
    sta SQ1_SWEEP.w
    sta SQ2_SWEEP.w

    ; enable noise, triangle, squares, but not dpcm (as it would start playing immediately).
	lda #SNDENA_NOISE|SNDENA_TRI|SNDENA_SQ2|SNDENA_SQ1
	sta SND_CHN.w

    ; enable MMC5 squares
    lda #SNDENA_MMC5_PULSE2|SNDENA_MMC5_PULSE1
    sta MMC5_STATUS.w

    ; todo: reset structs/other control bytes

    ; begin playing empty song.
    lda #MUS_SILENCE
    ; FALLTHROUGH

nse_playSound:
    cmp #MUS_PRELUDE
    beq @setup_MUS_PRELUDE
    cmp #MUS_SILENCE
    bne nse_updateSound_rts

@setup_MUS_SILENCE:
@setup_MUS_PRELUDE:
    ; set song to empty song
    lda #<nse_emptySong
    sta wMacro@Song.w
    lda #>nse_emptySong
    sta wMacro@Song+1.w

@initMusic:
    ; default values for music
    ldx #$01
    stx wMusTicksToNextRow_a1.w
    stx wMusRowsToNextFrame_a1.w
    ldx #SONG_MACRO_DATA_OFFSET
    stx wMacro@Song+2.w ; song start

    ; load channel dataset pointer
    copy_word_X wMacro@Song.w, wSoundBankTempAddr2.b

    ; wMusChannel_ReadNibble <- 0
    lda #$0
    sta wMusChannel_ReadNibble.w

    lda #$0
    
    ; initialize music channel state
    ; loop(channels)
    ldy #NUM_CHANS
-   sta wMusChannel_BaseVolume-1.w, y
    sta wMusChannel_ArpXY-1.w, y
    ; no need to set pitch; volume is 0.
    dey
    bne -

    ; initialize channel macros to 0
    ldy #(wMacro_end - wMacro_start)
-   sta wMacro_start, y
    dey
    cpy #(wMacro_Chan_Base - wMacro_start)
    bne -

    ; set instrument table addresses (for caching reasons)
    ; loop(channels)
    ldy #(NUM_CHANS*2)

-   ; wMusChannel_InstrTableAddr[channel] <- song.channelDatasetAddr[channel]
    lda (wSoundBankTempAddr2), Y
    sta wMusChannel_InstrTableAddr-1, Y
    dey
    bne -
    ;fallthrough

nse_updateSound_rts:
    rts


nse_updateSound:
@nse_updateMusic:
    ; if (wMusTicksToNextRow-- != 0) goto @frameTick;
    dec wMusTicksToNextRow_a1.w
    bne @frameTick

;------------------------------------------------
; New Phrase row
;------------------------------------------------
@nse_advanceRow:
    ; increment groove.
    ; if we exceed the groove length, we'll notice this later.
    inc wMusGrooveSubIdx.w

    ; if (wMusRowsToNextFrame-- == 0), then advance frame
    dec wMusRowsToNextFrame_a1.w
    bne @nse_advanceChannelRow

@nse_advanceFrame:
    ; get frame length from song data
    jsr nse_nextSongByte
    sta wMusRowsToNextFrame_a1.w

    ; loop(channels)
    copy_byte_immA NUM_CHANS-1, wChannelIdx
-   jsr nse_nextSongByte
    jsr nse_setChannelPhrase

    ; wMusChannel_RowsToNextCommand[channel_idx] <- 0
    lda #$1
    ldx wChannelIdx
    sta wMusChannel_RowsToNextCommand_a1.w, x
    dec wChannelIdx
    bpl -

@nse_advanceChannelRow:
    ; wMusTicksToNextRow <- getGrooveValue()

    lda #$9 ; TODO: jsr getGrooveValue_a1

    sta wMusTicksToNextRow_a1.w

    ; loop(channels_a1)
    ldx #NUM_CHANS
-   dec wMusChannel_RowsToNextCommand_a1-1.w, x
    bne + ; next instrument

    stx wChannelIdx_a1 ; store x
    jsr nse_execChannelCommands
    ldx wChannelIdx_a1 ; pop x
+   dex
    beq -

@frameTick:
    rts
;------------------------------------------------
; New Note tick
;------------------------------------------------

@mixOut:
    ; write active mixed channel to register
    ; loop(channels)
    copy_byte_immA NUM_CHANS-1, wChannelIdx
-   jsr nse_mixOutTick
    dec wChannelIdx
    bpl -
    rts

;------------------------------------------------
; subroutines
;------------------------------------------------

.include "code/newSoundEngineCommands.s"

; input:
;  wChannelIdx = channel
;  (word) wSoundBankTempAddr2 = wMacro@song
;  A = phrase idx
; clobber: AXY
; result:
;   channel phrase <- channel.phrasetable[A]
;   channel phrase row <- 0
nse_setChannelPhrase:
    ;assert wMacro_phrases - wMacro_start == NSE_SIZEOF_MACRO, "this function requires phrases start at idx 1"
    
    ; (store input A)
    tax

    ; wMusChannel_RowsToNextCommand[wChannelIdx] <- 0
    ldy wChannelIdx
    lda #$1
    sta wMusChannel_RowsToNextCommand_a1, y

    ; gv0 <- 2 * wChannelIdx
    ; Y <- 2 * wChannelIdx + 1
    tya
    asl ; -C
    sta wNSE_genVar0
    tay
    iny

    ; (word) wSoundBankTempAddr1 <- song@channelDatasetAddr[wChannelIdx]
    lda (wSoundBankTempAddr2), y
    sta wSoundBankTempAddr1
    iny
    lda (wSoundBankTempAddr2), y
    sta wSoundBankTempAddr1+1

    ; Y <- (input A)
    txa
    tay

    ; X <- 3 * wChannelIdx
    lda wNSE_genVar0 ; note: -C from before.
    adc wChannelIdx
    tax

    ; 
    lda (wSoundBankTempAddr1), y
    sta wMacro_phrase.w, x
    iny
    lda (wSoundBankTempAddr1), y
    sta wMacro_phrase+1.w, x

    ; channel row <- 0
    lda #$1
    sta wMacro_phrase+2.w, x

    rts

.define hardwareOut wSoundBankTempAddr1

nse_mixOutTickNoise:
nse_mixOutTickDPCM:
    plp
    rts

; input: wChannelIdx = channel
nse_mixOutTick:
    ; push processor status (interrupt flags)
    php

    ; X <- channel idx
    ; (word) hardwareOut <- base of output registers.
    ldx wChannelIdx
    lda _nse_hardwareTable_lo.w, x
    sta hardwareOut.w
    lda _nse_hardwareTable_hi.w, x
    sta hardwareOut+1.w

    ; dispatch depending on channel
    dex
    dex
    beq nse_mixOutTickTri
    dex
    beq nse_mixOutTickNoise
    dex
    beq nse_mixOutTickDPCM
    jmp nse_mixOutTickSq

.define nibbleParity wNSE_genVar6

nse_mixOutTickTri_State:
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
    bpl @loop_start

    ; increment timer
    inc wMacro@Tri_Length+2.w

    ; load (un)mute value of final macro byte
    lda wNSE_genVar5

@post_loop:
    bpl nse_mixOutTickTri@setUnmuted
    bmi nse_mixOutTickTri@setMuted ; guaranteed

nse_mixOutTickTri:
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
    lda wMusChannel_BaseVolume+NSE_TRI.w
    beq @setMuted

    ; if macro address is odd, this is a State macro; otherwise, Length.
    lda wMacro@Tri_Length+1.w
    beq @setUnmuted ; no state/length macro -- set unmuted
    lsr
    bcs nse_mixOutTickTri_State

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
    pha ; push volume
    ldy NSE_TRI ; this is wChannelIdx
    ; read arp and detune macros as normal.
    jmp nse_mixOutTickSq@setFrequency

nse_mixOutTickSq_volzero:
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
    sta wNSE_genVar0
    bpl nse_mixOutTickSq@setDutyCycle ; guaranteed jump (base channel top nibble is 0)

nse_mixOutTickSq:
    ; wSoundBankTempAddr <- nse_hardwareTable[y]
    ldx wChannelIdx

    ; nibbleParity set to 0/nonzero later on.
    lda #$1
    sta nibbleParity

@setVolume:
    ; ------------------------------------------
    ; volume
    ; ------------------------------------------
    lda channelMacroVolAddrTable_a2.w, x
    sta wNSE_genVar5; store in gv5 so duty cycle can reuse this later
    tax
    lda wMacro_start.w, x
    sta wNSE_genVar0 ; store current macro offset
    dex
    dex
    lda wMacro_start+1.w, x
    beq nse_mixOutTickSq_volzero ; special handling for instruments without volume macro.
    nse_nextMacroByte_inline_precalc_abaseaddr
    sta wNSE_genVar1 ; store macro volume multiplier

    ; restore previous macro offset if nibble is even
    ldy wChannelIdx
    lda bitIndexTable, y
    tay
    inx
    inx
    ; start condition: nibble is 0 on even frames.
    and wMusChannel_ReadNibble.w
    bne +
    sta nibbleParity ; on even frames, nibbleParity is 0.
    lda wNSE_genVar0 ; restore previous macro offset (on even frames)
    sta wMacro_start.w, x
    ; shift to upper nibble if loading even macro
    lda wNSE_genVar1
    shift 4
    sta wNSE_genVar1

+   ; wMusChannel_ReadNibble ^= (1 << channel idx)
    tya
    eor wMusChannel_ReadNibble.w
    sta wMusChannel_ReadNibble.w

    ; crop out lower portion of macro's nibble
    lda wNSE_genVar1
    and #$f0
    sta wNSE_genVar1

    ; multiply tmp volume with base volume.
    lda wMusChannel_BaseVolume, y ; assumption: base volume upper nibble is 0.
    eor wNSE_genVar1 ; ora, eor -- it doesn't matter
    tax
    lda volumeTable.w, x
    sta wNSE_genVar0 ; genVar0 <- volume

@setDutyCycle:
    ; A <- duty cycle macro value, wNSE_genVar5 <- previous duty cycle offset value
    ldx wNSE_genVar5
    nse_nextMacroByte_inline_precalc wNSE_genVar5
    ldy nibbleParity
    bne +
        ; even frame -- restore previous macro offset and shift up nibble.
        shift 4
        lda wNSE_genVar5
        sta wMacro_start+2.w, x
    + ; TODO: 4x-packed duty cycle values?
    ; assumption: macro bytes 4 and 5 are 1.
    and #$F0
    ora wNSE_genVar0 ; OR with volume
    pha ; store volume for later.

@setFrequency:
    ; ------------------------------------------
    ; frequency
    ; ------------------------------------------
    ; get arpeggio (pitch offset)
    ; precondition: y = channel idx

    ; x <- offset of arp address
    ldx channelMacroArpAddrTable.w, y
    stx wNSE_genVar5 ; store offset for arp macro table

    ; A <- next arpeggio macro value
    lda wMacro_start+1.w, x ; skip if macro is zero.
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

    ; optimization: skip altogether if macro value is 0 (i.e. there is no macro).
    beq @endArpXYAdjustCLC

    ; apply ArpXY to arpeggio offset
@ArpXYAdjust:
    bit wNSE_genVar1 ; N <- ArpX, Z <- ArpY
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
    bpl @lookupFrequencyX

@ArpY_UnkX:
    bmi @endArpXYAdjustCLC
@ArpY:
    lda wMusChannel_ArpXY, y
    shift -4
    clc
    adc arpValue
    bcc @endArpXYAdjust ; guaranteed -- as above.

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
    adc arpValue ; (-C still)
    tax
@lookupFrequencyX:
    lda pitchFrequencies_lo.w, x
    sta wSoundFrequency
    lda pitchFrequencies_hi.w, x
    sta wSoundFrequency+1

    ; detune
    ; (-C from above)
    ; X <- macro table offset for detune
    lda #$3
    adc wNSE_genVar5 ; macro table offset for Arp
    tax
    lda wMacro_start+2.w, x
    sta wNSE_genVar0 ; store previous macro idx for later

    ; A <- next detune value
    lda wMacro_start.w+1, x ; skip if macro is zero.
    beq @doneDetune
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

    ; wSoundBankTempAddr2 is macro base address; the byte before it is the base detune offset.
    ldy #$0
    dec wSoundBankTempAddr2
    clc
    adc (wSoundBankTempAddr2), y
    bpl @subtractFrequency
@addFrequency:
    ; add detune to frequency.
    and #$7F ; remove sign byte
    clc
    adc wSoundFrequency.w
    sta wSoundFrequency.w
    bcc @doneDetune
    inc wSoundFrequency+1.w
    bpl @doneDetune ; guaranteed

@subtractFrequency:
    ; add sign byte
    ora #$80
    clc
    adc wSoundFrequency.w
    sta wSoundFrequency.w
    bcs @doneDetune
    dec wSoundFrequency+1.w

@doneDetune:

@writeRegisters:
    ldx wChannelIdx
    ldy #$0
    lda #%00110000
    cpx TRI_LINEAR

    ; CRITICAL SECTION ------------------------------------------
    ; prevent interrupts during this critical section

    ; set volume to zero in case APU update occurs during this period
    sei ; disable interrupts
    beq + ; (branch if triangle channel)
        sta (hardwareOut), y

+   ; write frequency to hardware out, but only if high value has changed.
    ldy #$3
    lda (hardwareOut), y
    and #%00000111 ; frequency high only 3 bits
    cmp wSoundFrequency+1
    beq +
        lda wSoundFrequency+1
        sta (hardwareOut), y
        dey
        lda wSoundFrequency
        sta (hardwareOut), y
  + pla ; retrieve volume.
    ldy #$0
    sta (hardwareOut), y

    ; apply mute immediately if triangle channel needs muting.
    lda wMusTri_Prev.w
    bmi @doTriMute ; if mute not pending
    plp ; restore interrupt status
    ; END CRITICAL SECTION --------------------------------------

    rts

@doTriMute:
    ; APU_FRAME_CTR <- $80
    sta APU_FRAME_CTR
    asl ; A <- 0
    ; unmark pending mute
    sta wMusTri_Prev.w

    plp
    ; END CRITICAL SECTION (alt) --------------------------------

    rts

nse_silenceAllSoundChannels:
    lda #$30
    sta SQ1_VOL.w
    sta SQ2_VOL.w
    sta TRI_LINEAR.w
    sta NOISE_VOL.w
    sta MMC5_PULSE1_VOL.w
    sta MMC5_PULSE2_VOL.w
    rts

; pointers to hardware struct for each channel
_nse_hardwareTable_lo:
    .db <SQ1_VOL
    .db <SQ2_VOL
    .db <TRI_LINEAR
    .db UNUSED
    .db UNUSED
    .db <MMC5_PULSE1_VOL
    .db <MMC5_PULSE2_VOL

_nse_hardwareTable_hi:
    .db >SQ1_VOL
    .db >SQ2_VOL
    .db >TRI_LINEAR
    .db UNUSED
    .db UNUSED
    .db >MMC5_PULSE1_VOL
    .db >MMC5_PULSE2_VOL

pitchFrequencies_hi:
    .db $07 ; A-0
    .db $07 ; A#0
    .db $07 ; B-0
    .db $06 ; C-1
    .db $06 ; C#1
    .db $05 ; D-1
    .db $05 ; D#1
    .db $05 ; E-1
    .db $04 ; F-1
    .db $04 ; F#1
    .db $04 ; G-1
    .db $04 ; G#1
    .db $03 ; A-1
    .db $03 ; A#1
    .db $03 ; B-1
    .db $03 ; C-2
    .db $03 ; C#2
    .db $02 ; D-2
    .db $02 ; D#2
    .db $02 ; E-2
    .db $02 ; F-2
    .db $02 ; F#2
    .db $02 ; G-2
    .db $02 ; G#2
    .db $01 ; A-2
    .db $01 ; A#2
    .db $01 ; B-2
    .db $01 ; C-3
    .db $01 ; C#3
    .db $01 ; D-3
    .db $01 ; D#3
    .db $01 ; E-3
    .db $01 ; F-3
    .db $01 ; F#3
    .db $01 ; G-3
    .db $01 ; G#3
    .db $00 ; A-3
    .db $00 ; A#3
    .db $00 ; B-3
    .db $00 ; C-4
    .db $00 ; C#4
    .db $00 ; D-4
    .db $00 ; D#4
    .db $00 ; E-4
    .db $00 ; F-4
    .db $00 ; F#4
    .db $00 ; G-4
    .db $00 ; G#4
    .db $00 ; A-4
    .db $00 ; A#4
    .db $00 ; B-4
    .db $00 ; C-5
    .db $00 ; C#5
    .db $00 ; D-5
    .db $00 ; D#5
    .db $00 ; E-5
    .db $00 ; F-5
    .db $00 ; F#5
    .db $00 ; G-5
    .db $00 ; G#5
    .db $00 ; A-5
    .db $00 ; A#5
    .db $00 ; B-5
    .db $00 ; C-6
    .db $00 ; C#6
    .db $00 ; D-6
    .db $00 ; D#6
    .db $00 ; E-6
    .db $00 ; F-6
    .db $00 ; F#6
    .db $00 ; G-6
    .db $00 ; G#6
    .db $00 ; A-6
    .db $00 ; A#6
    .db $00 ; B-6
    .db $00 ; C-7
    .db $00 ; C#7
    .db $00 ; D-7

pitchFrequencies_lo:
    ; detuned from 440 Hz specifically for AoC.
    
    .db $DC ; A-0
    .db $6B ; A#0
    .db $00 ; B-0
    .db $9C ; C-1
    .db $ED ; C#1
    .db $E3 ; D-1
    .db $8E ; D#1
    .db $3E ; E-1
    .db $F3 ; F-1
    .db $AC ; F#1
    .db $69 ; G-1
    .db $29 ; G#1
    .db $ED ; A-1
    .db $B5 ; A#1
    .db $80 ; B-1
    .db $4D ; C-2
    .db $1E ; C#2
    .db $F1 ; D-2
    .db $C7 ; D#2
    .db $9F ; E-2
    .db $79 ; F-2
    .db $55 ; F#2
    .db $34 ; G-2
    .db $14 ; G#2
    .db $F6 ; A-2
    .db $DA ; A#2
    .db $BF ; B-2
    .db $A6 ; C-3
    .db $8E ; C#3
    .db $78 ; D-3
    .db $63 ; D#3
    .db $4F ; E-3
    .db $3C ; F-3
    .db $2A ; F#3
    .db $19 ; G-3
    .db $0A ; G#3
    .db $FB ; A-3
    .db $EC ; A#3
    .db $DF ; B-3
    .db $D8 ; C-4
    .db $C7 ; C#4
    .db $BB ; D-4
    .db $B1 ; D#4
    .db $A7 ; E-4
    .db $9D ; F-4
    .db $95 ; F#4
    .db $8C ; G-4
    .db $84 ; G#4
    .db $7D ; A-4
    .db $76 ; A#4
    .db $6F ; B-4
    .db $69 ; C-5
    .db $63 ; C#5
    .db $6D ; D-5
    .db $58 ; D#5
    .db $53 ; E-5
    .db $4E ; F-5
    .db $4A ; F#5
    .db $46 ; G-5
    .db $42 ; G#5
    .db $3E ; A-5
    .db $3A ; A#5
    .db $37 ; B-5
    .db $34 ; C-6
    .db $31 ; C#6
    .db $2E ; D-6
    .db $2B ; D#6
    .db $29 ; E-6
    .db $27 ; F-6
    .db $24 ; F#6
    .db $22 ; G-6
    .db $20 ; G#6
    .db $1E ; A-6
    .db $1D ; A#6
    .db $1B ; B-6
    .db $19 ; C-7
    .db $18 ; C#7
    .dw $17 ; D-7

nse_emptySong:
    .db SONG_MACRO_DATA_OFFSET
    .dsw NUM_CHANS, @nse_emptyChannelData ; channel data table
    .db $10 ; use the first pattern (empty music pattern)
    .db 0 ; end of loop

@nse_emptyChannelData:
@nse_nullTablePtr:
.rept $10
    .dw nullTable
.endr
@nse_silentPhrasePtr:
    .dw nse_silentPhrase

    
nse_silentPhrase:
    .db 1
    .db $5F
    .db 0

channelMacroVolAddrTable_a2:
    .db wMacro@Sq1_Vol-wMacro_start+2
    .db wMacro@Sq1_Vol-wMacro_start+2
    .db UNUSED
    .db wMacro@Noise_Vol-wMacro_start+2
    .db UNUSED
    .db wMacro@Sq3_Vol-wMacro_start+2
    .db wMacro@Sq4_Vol-wMacro_start+2
channelMacroArpAddrTable:
channelMacroBaseAddrTable:
    .db wMacro_Sq1_Base-wMacro_start
    .db wMacro_Sq1_Base-wMacro_start
    .db wMacro_Tri_Base-wMacro_start
    .db wMacro_Noise_Base-wMacro_start
    .db UNUSED
    .db wMacro_Sq3_Base-wMacro_start
    .db wMacro_Sq4_Base-wMacro_start
channelMacroEndAddrTable:
    .db wMacro_Sq1_End-wMacro_start
    .db wMacro_Sq2_End-wMacro_start
    .db wMacro_Tri_End-wMacro_start
    .db wMacro_Noise_End-wMacro_start
    .db UNUSED
    .db wMacro_Sq3_End-wMacro_start
    .db wMacro_Sq4_End-wMacro_start
bitIndexTable:
    .db $01 $02 $04 $08 $10 $20 $40 $80

volumeTable:
    .db     15,14,13,12,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
    .db     14,13,12,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 1, 0
    .db     13,12,11,10, 9, 8, 7, 6, 6, 5, 4, 3, 2, 1, 1, 0
    .db     12,11,10, 9, 8, 8, 7, 6, 5, 4, 4, 3, 2, 1, 1, 0
    .db     11,10, 9, 8, 8, 7, 6, 5, 5, 4, 3, 2, 2, 1, 1, 0
    .db     10, 9, 8, 8, 7, 6, 6, 5, 4, 4, 3, 2, 2, 1, 1, 0
    .db      9, 8, 7, 7, 6, 6, 5, 4, 4, 3, 3, 2, 1, 1, 1, 0
    .db      8, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 1, 0
    .db      7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 1, 1, 0
    .db      6, 5, 5, 4, 4, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 0
    .db      5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 0
    .db      4, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 0
    .db      3, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0
    .db      2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0
    .db      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
nullTable: ; 32 zeros in a row (also part of volume table above)
    .rept 32
    .db      0
    .endr