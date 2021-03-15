.include "code/newSoundEngineMacro.s"

.define SQ3_VOL MMC5_PULSE1_VOL
.define SQ3_LO MMC5_PULSE1_LO
.define SQ3_HI MMC5_PULSE1_HI
.define SQ4_VOL MMC5_PULSE2_VOL
.define SQ4_LO MMC5_PULSE2_LO
.define SQ4_HI MMC5_PULSE2_HI

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
    lda #$0
    sta wSFXChannelActive.w

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
    
    ; initialize music channel state
    ; loop(channels)
    ldy #NUM_CHANS
-   lda #$0
    sta wMusChannel_BaseVolume-1.w, y
    sta wMusChannel_ArpXY-1.w, y
    lda #$80
    sta wMusChannel_BaseDetune-1.w, y
    ; no need to set pitch; volume is 0.
    dey
    bne -

    lda #$0
    sta wMusChannel_ReadNibble.w ; (paranoia)
    sta wMusChannel_Portamento.w

    ; initialize channel macros and groove to 0
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
    .define MACRO_BYTE_ABSOLUTE wMacro@Groove-wMacro_start
    nse_nextMacroByte_inline_precalc
    ; we don't need to add 1 as decrement occurs next frame.
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
    
;------------------------------------------------
; New Note tick (this runs every 60 Hz frame)
;------------------------------------------------

@mixOut:
    ; write active mixed channel to register
    ; loop(channels)
    copy_byte_immA NUM_CHANS-1, wChannelIdx
-   ldx wChannelIdx
    lda bitIndexTable.w, x
    and wSFXChannelActive.w
    sta wNSE_current_channel_is_unmasked
    bne @sfx_tick
@no_sfx_tick:
    jsr nse_musTick
    dec wChannelIdx
    bpl -
    bmi @writeRegisters ; end of loop

@sfx_tick:
    jsr nse_sfxTick

    ; check if masking ended as a result of the sfx update
    ldx wChannelIdx
    lda bitIndexTable.w, x
    and wSFXChannelActive.w
    beq @no_sfx_tick ; if masking ended this frame, go update music as per usual instead.

    ; "masked" update music tick
    jsr nse_musTick
    dec wChannelIdx
    bpl -

@writeRegisters:
    ; CRITICAL SECTION ---------------------------
    php

    ; write triangle registers
    lda wMix_CacheReg_Tri_Vol.w
    ldx wMix_CacheReg_Tri_Lo.w
    ldy wMix_CacheReg_Tri_Hi.w
    sei
    sta TRI_LINEAR
    stx TRI_LO
    sty TRI_HI

    ; write square registers
    .macro sqregset
        lda wMix_CacheReg_Sq\1_Vol.w
        sta SQ\1_VOL

        lda wMix_CacheReg_Sq\1_Lo.w
        sta SQ\1_LO

        ; only update Hi if it has changed
        lda wMix_CacheReg_Sq\1_Hi.w
        eor SQ\1_HI
        and #%00000111
        beq +
        sta SQ\1_HI
        +
    .endm

    sqregset 1
    sqregset 2
    sqregset 3
    sqregset 4

    ; noise channel
    lda wMix_CacheReg_Noise_Vol.w
    sta NOISE_VOL

    lda wMix_CacheReg_Noise_Lo.w
    sta NOISE_LO
    
    ; triangle channel needs special attention afterward
    ; (need to mute sometimes)
    lda wMusTri_Prev.w ;
    bpl +

    ;   perform triangle mute
    ;   A = wMusTri_Prev, which must be $80 at this point
    ;   (bit 7 = pending mute, bit 6 = currently unmuted)
    ;   (cannot have a pending mute while not currently muted)
    sta APU_FRAME_CTR
    asl ; A <- 0
    sta wMusTri_Prev.w ; unmark pending mute

+   plp
    ; END CRITICAL SECTION ----------------------

    ; end of nse_updateSound ---------------------
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

.include "code/newSoundEngineMusTick.s"
.include "code/newSoundEngineSFXTick.s"

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
    .db <NOISE_VOL
    .db UNUSED
    .db <MMC5_PULSE1_VOL
    .db <MMC5_PULSE2_VOL

_nse_hardwareTable_hi:
    .db >SQ1_VOL
    .db >SQ2_VOL
    .db >TRI_LINEAR
    .db >NOISE_VOL
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

channelMacroVibratoTable:
    .db wMacro@Sq1_Vib-wMacro_start
    .db wMacro@Sq2_Vib-wMacro_start
    .db wMacro@Tri_Vib-wMacro_start
    .db 0 ; 0 lets us beq to skip this.
    .db 0
    .db wMacro@Sq3_Vib-wMacro_start
    .db wMacro@Sq4_Vib-wMacro_start

channelMacroVolAddrTable_a2:
    .db wMacro@Sq1_Vol-wMacro_start+2
    .db wMacro@Sq1_Vol-wMacro_start+2
    .db UNUSED
    .db wMacro@Noise_Vol-wMacro_start+2
    .db UNUSED
    .db wMacro@Sq3_Vol-wMacro_start+2
    .db wMacro@Sq4_Vol-wMacro_start+2
channelMacroPortamentoAddrTable:
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