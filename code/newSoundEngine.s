.include "code/newSoundEngineMacro.s"

; Channels - SQ/2, TRI, NOISE, DPCM, MMC5 PULSE 1/2, CONDUCTOR
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

    ; default values for music channels
    lda #$0
    ldx #NUM_NON_CONDUCTOR_CHANS-1
-   sta wMusChannel_BaseVolume, 0
    dex
    bpl -

    ; todo: reset structs/other control bytes

    ; begin playing empty song.
    lda #MUS_SILENCEund
    ; FALLTHROUGH

nse_playSound:
    cmp #MUS_PRELUDE
    beq @setup_MUS_PRELUDE
    cmp #MUS_SILENCE
    bne nse_updateSound_rts ; guaranteed

@setup_MUS_SILENCE:
@setup_MUS_PRELUDE:
    ; set song to empty song
    lda #<nse_emptySong
    sta wMacro.Song
    lda #>nse_emptySong
    sta wMacro.Song+1

@initMusic:
    ; default values for music
    ldx #$01
    stx wMusTicksToNextRow_a1
    stx wMusRowsToNextFrame_a1
    ldx #SONG_MACRO_DATA_OFFSET
    stx wMacro.Song+2 ; song start

    ; load channel dataset pointer
    copy_word_X wMacro.Song, wSoundBankTempAddr2

    ; set instrument table addresses (for caching reasons)
    ; loop(channels)
    ldy #(NUM_NON_CONDUCTOR_CHANS*2 + 1)

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
    ; (word) wSoundBankTempAddr <- wMacro.Song
    lda wMacro.Song
    sta wSoundBankTempAddr1
    lda wMacro.Song+1
    sta wSoundBankTempAddr1+1

    ; get frame length from song data
    jsr nse_getSongByte
    sta wMusRowsToNextFrame_a1

    ; loop(channels)
    copy_byte_A #NUM_CHANS-1, wChannelIdx
-   jsr nse_getSongByte
    jsr nse_setChannelPhrase

    ; wMusChannel_RowsToNextCommand <- 0
    copy_byte_A #$1, wMusChannel_RowsToNextCommand_a1
    dec wChannelIdx
    bpl -

@nse_advanceChannelRow:
    ; wMusTicksToNextRow <- getGrooveValue()

    lda #$9 ; TODO: jsr getGrooveValue_a1

    sta wMusTicksToNextRow_a1

    ; loop(channels_a1)
    ldx #NUM_CHANS
-   dec wMusChannel_RowsToNextCommand_a1-1, x
    bne + ; next instrument

    stx wChannelIdx_a1 ; store x
    jsr nse_execChannelCommands
    ldx wChannelIdx_a1 ; pop x
+   dex
    beq -

@frameTick:
;------------------------------------------------
; New Note tick
;------------------------------------------------

    ; tick for each channel
    ; loop(channels)
    copy_byte_A #NUM_NON_CONDUCTOR_CHANS, wChannelIdx
-   jsr nse_noteTick
    dec wChannelIdx
    bpl -
    rts

;------------------------------------------------
; subroutines
;------------------------------------------------

.include "code/newSoundEngineCommands.s"

; input:
;  wChannelIdx = channel
;  (word) wSoundBankTempAddr1 = wMacro.song
; clobber: AXY
; result:
;   channel phrase <- channel.phrasetable[A]
;   channel phrase row <- 0
nse_setChannelPhrase:
    assert wMacro.phrases - wMacro.start == NSE_SIZEOF_MACRO, "this function requires phrases start at idx 1"
    
    ; (store input A)
    tax

    ; wMusChannel_RowsToNextCommand[wChannelIdx] <- 0
    ldy wChannelIdx
    lda #$1
    sta wMusChannel_RowsToNextCommand_a1, y

    ; Y <- 2 * wChannelIdx
    ; push Y
    tya
    asl ; -C
    pha
    tay

    ; (word) wSoundBankTempAddr1 <- wMacro.song@channelDatasetAddr[wChannelIdx]
    lda (wSoundBankTempAddr1), y
    sta wSoundBankTempAddr2
    iny
    lda (wSoundBankTempAddr1), y
    sta wSoundBankTempAddr2+1

    ; Y <- (input A)
    txa
    tay

    ; X <- 3 * wChannelIdx + 1
    pla ; note: -C from before.
    adc wChannelIdx
    tax

    ; (word) wSoundBankTempAddr2 <- phrase pointer
    lda (wSoundBankTempAddr2), y
    sta wMacro.phrase, x
    iny
    lda (wSoundBankTempAddr2), y
    sta wMacro.phrase+1, x

    ; channel row <- 0
    lda #$1
    sta wMacro.phrase+2, x

    rts

; input: wChannelIdx = channel
nse_noteTick:
    lda wChannelIdx
    asl
    tay
    jsr jumpTableNoPreserveY
; subroutines for each channel's noteTick
@nse_noteTick_JumpTable:
    .dw nse_noteTickSq
    .dw nse_noteTickSq
    .dw nse_noteTickTri
    .dw nse_noteTickNoise
    .dw nse_noteTickDPCM
    .dw nse_noteTickSq
    .dw nse_noteTickSq

; pointers to hardware struct for each channel
@nse_hardwareTable_lo:
    .db <SQ1_VOL
    .db <SQ2_VOL
    .db ; unused
    .db ; unused
    .db ; unused
    .db <MMC5_PULSE1_VOL
    .db <MMC5_PULSE2_VOL

@nse_hardwareTable_hi:
    .db >SQ1_VOL
    .db >SQ2_VOL
    .db ; unused
    .db ; unused
    .db ; unused
    .db >MMC5_PULSE1_VOL
    .db >MMC5_PULSE2_VOL

nse_noteTickSq:
    ; wSoundBankTempAddr <- nse_hardwareTable[y]
    ldy wChannelIdx
    lda nse_hardwareTable_lo, y
    sta wSoundBankTempAddr1
    lda nse_hardwareTable_hi, y
    sta wSoundBankTempAddr1+1

    ; set volume
    lda wMusChannel_BaseVolume, y
    ldx #$0
    sta (wSoundBankTempAddr1, x)

    ; set frequency lo
    ldx wMusChannel_BasePitch, y
    lda pitchFrequencies_lo, x
    ldy #$2
    sta (wSoundBankTempAddr1), y
    
    ; set frequency hi, but only if it has changed.
    iny
    lda (wSoundBankTempAddr1), y
    and #$7 ; frequency high top 7 bits are distinct.
    cmp pitchFrequencies_hi, x
    beq +
    lda pitchFrequencies_hi, x
    sta (wSoundBankTempAddr1), y
  + rts

nse_noteTickTri:
    rts

nse_noteTickNoise:
    rts

nse_noteTickDPCM:
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

pitchFrequencies_hi:
    .dw $07 ; A-0
    .dw $07 ; A#0
    .dw $07 ; B-0
    .dw $06 ; C-1
    .dw $06 ; C#1
    .dw $05 ; D-1
    .dw $05 ; D#1
    .dw $05 ; E-1
    .dw $04 ; F-1
    .dw $04 ; F#1
    .dw $04 ; G-1
    .dw $04 ; G#1
    .dw $03 ; A-1
    .dw $03 ; A#1
    .dw $03 ; B-1
    .dw $03 ; C-2
    .dw $03 ; C#2
    .dw $02 ; D-2
    .dw $02 ; D#2
    .dw $02 ; E-2
    .dw $02 ; F-2
    .dw $02 ; F#2
    .dw $02 ; G-2
    .dw $02 ; G#2
    .dw $01 ; A-2
    .dw $01 ; A#2
    .dw $01 ; B-2
    .dw $01 ; C-3
    .dw $01 ; C#3
    .dw $01 ; D-3
    .dw $01 ; D#3
    .dw $01 ; E-3
    .dw $01 ; F-3
    .dw $01 ; F#3
    .dw $01 ; G-3
    .dw $01 ; G#3
    .dw $00 ; A-3
    .dw $00 ; A#3
    .dw $00 ; B-3
    .dw $00 ; C-4
    .dw $00 ; C#4
    .dw $00 ; D-4
    .dw $00 ; D#4
    .dw $00 ; E-4
    .dw $00 ; F-4
    .dw $00 ; F#4
    .dw $00 ; G-4
    .dw $00 ; G#4
    .dw $00 ; A-4
    .dw $00 ; A#4
    .dw $00 ; B-4
    .dw $00 ; C-5
    .dw $00 ; C#5
    .dw $00 ; D-5
    .dw $00 ; D#5
    .dw $00 ; E-5
    .dw $00 ; F-5
    .dw $00 ; F#5
    .dw $00 ; G-5
    .dw $00 ; G#5
    .dw $00 ; A-5
    .dw $00 ; A#5
    .dw $00 ; B-5
    .dw $00 ; C-6
    .dw $00 ; C#6
    .dw $00 ; D-6
    .dw $00 ; D#6
    .dw $00 ; E-6
    .dw $00 ; F-6
    .dw $00 ; F#6
    .dw $00 ; G-6
    .dw $00 ; G#6
    .dw $00 ; A-6
    .dw $00 ; A#6
    .dw $00 ; B-6
    .dw $00 ; C-7
    .dw $00 ; C#7
    .dw $00 ; D-7

pitchFrequencies_lo:
    ; detuned from 440 Hz specifically for AoC.
    
    .dw $DC ; A-0
    .dw $6B ; A#0
    .dw $00 ; B-0
    .dw $9C ; C-1
    .dw $ED ; C#1
    .dw $E3 ; D-1
    .dw $8E ; D#1
    .dw $3E ; E-1
    .dw $F3 ; F-1
    .dw $AC ; F#1
    .dw $69 ; G-1
    .dw $29 ; G#1
    .dw $ED ; A-1
    .dw $B5 ; A#1
    .dw $80 ; B-1
    .dw $4D ; C-2
    .dw $1E ; C#2
    .dw $F1 ; D-2
    .dw $C7 ; D#2
    .dw $9F ; E-2
    .dw $79 ; F-2
    .dw $55 ; F#2
    .dw $34 ; G-2
    .dw $14 ; G#2
    .dw $F6 ; A-2
    .dw $DA ; A#2
    .dw $BF ; B-2
    .dw $A6 ; C-3
    .dw $8E ; C#3
    .dw $78 ; D-3
    .dw $63 ; D#3
    .dw $4F ; E-3
    .dw $3C ; F-3
    .dw $2A ; F#3
    .dw $19 ; G-3
    .dw $0A ; G#3
    .dw $FB ; A-3
    .dw $EC ; A#3
    .dw $DF ; B-3
    .dw $D8 ; C-4
    .dw $C7 ; C#4
    .dw $BB ; D-4
    .dw $B1 ; D#4
    .dw $A7 ; E-4
    .dw $9D ; F-4
    .dw $95 ; F#4
    .dw $8C ; G-4
    .dw $84 ; G#4
    .dw $7D ; A-4
    .dw $76 ; A#4
    .dw $6F ; B-4
    .dw $69 ; C-5
    .dw $63 ; C#5
    .dw $6D ; D-5
    .dw $58 ; D#5
    .dw $53 ; E-5
    .dw $4E ; F-5
    .dw $4A ; F#5
    .dw $46 ; G-5
    .dw $42 ; G#5
    .dw $3E ; A-5
    .dw $3A ; A#5
    .dw $37 ; B-5
    .dw $34 ; C-6
    .dw $31 ; C#6
    .dw $2E ; D-6
    .dw $2B ; D#6
    .dw $29 ; E-6
    .dw $27 ; F-6
    .dw $24 ; F#6
    .dw $22 ; G-6
    .dw $20 ; G#6
    .dw $1E ; A-6
    .dw $1D ; A#6
    .dw $1B ; B-6
    .dw $19 ; C-7
    .dw $18 ; C#7
    .dw $17 ; D-7

nse_emptySong:
    .db SONG_MACRO_DATA_OFFSET
    .dsw $10, @nse_emptyMusicPatternLoc-$10
    .db $10 ; use the first pattern (empty music pattern)
    .db 0
@nse_emptyMusicPatternLoc:
    .dw nse_silentMusicPattern
    

nse_silentMusicPattern:
    .db 3
    .db 4F

nse_emptyMusicPattern:
; this pattern loops and does nothing for any music or sfx pattern
    .db 1
    .db 4E
    .db 4E
    .db 0