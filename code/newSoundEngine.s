.include "code/newSoundEngineMacro.s"

.define SQ3_VOL MMC5_PULSE1_VOL
.define SQ3_LO MMC5_PULSE1_LO
.define SQ3_HI MMC5_PULSE1_HI
.define SQ4_VOL MMC5_PULSE2_VOL
.define SQ4_LO MMC5_PULSE2_LO
.define SQ4_HI MMC5_PULSE2_HI

; precondition:
;   A = sfxid
; result:
;   sets Z if sfxid is looping, otherwise ~Z
;
; note: if this is ever edited so that there exist
; non-looping sfx with lower priorities than looping sfx,
; then the following changes need to be made:
;  - insertion of looping sfx must eliminate all lower-priority non-looping sfx
;  - insertion of an sfx must fail if a looping sfx is encountered with a higher priority
; in all cases, looping sfx will always occupy the bottom of the pq.
.macro sfxid_is_looping
    cmp NSE_SFXIDX_LOOP_END
.endm

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

    ; fix noise length counter on.
    lda #$30
    sta NOISE_VOL
    lda #$F0
    sta NOISE_HI

    ; todo: reset structs/other control bytes
    lda #$0
    sta wSFXChannelActive.w

    ; begin playing empty song.
    lda #MUS_SILENCE
    ; FALLTHROUGH

; preconditions:
;   A = sound to play
;   (status flags set for A)
nse_playSound:
    beq nse_playSFX@rts1
@music_idx_comparison:
    cmp #SND_MUSIC_START
    bmi nse_playSFX
    jmp nse_playMusic
nse_playSFX:
    DUMMY_RTS
@setup_SFX:
    .define wSFX_setup_sfx_duration wNSE_genVar0
    .define wSFX_setup_sfxid wNSE_genVar1
    .define wSFX_setup_sfx_offset wNSE_genVar2
    .define wSFX_setup_pq_offset wNSE_genVar3
    .define wSFX_setup_top_pri_has_changed wNSE_genVar4
    .define wSFX_setup_remaining_pq_entries wNSE_genVar5
    .define wSFX_setup_queue_end wNSE_genVar6
    .define wSFX_setup_pq_full wNSE_genVar7

    ; sfxid <- A
    sta wSFX_setup_sfxid

    ; wSoundBankTempAddr2 <- address of sfx
    tay
    lda nse_soundTable_lo, y
    sta wSoundBankTempAddr2
    lda nse_soundTable_hi, y
    sta wSoundBankTempAddr2+1
    
    ; (1 per sfx channel, indiciating if sfx is on or off)
    ldx #$0
    stx wSFX_setup_pq_offset ; offset from pq base
    stx wSFX_setup_sfx_offset ; offset from sfx base
    stx wSFX_setup_top_pri_has_changed ; which channels top-pri sfx changed as a result of this function?
    stx wChannelIdx

    ; loop over sfx channels

@channelLoopTop:
   ; A <- duration for sfx's channel X
    ldy wSFX_setup_sfx_offset
    lda (wSoundBankTempAddr2), y

    ; if duration == 0, then the sfx does not use this channel.
    beq @jmp_nextChannel
@channelUsed: ; channel appears in sfx to be inserted
    ; attempt to insert into priority queue

    ; store sfx duration
    sta wSFX_setup_sfx_duration

    ; Y <- wSFX_setup_pq_offset
    ldy wSFX_setup_pq_offset

    ; determine if PQ is already full
    lda sfxPQ+NSE_SFX_QUEUE_NUM_ENTRIES-1.w, y
    sta wSFX_setup_pq_full

    ; cache the topmost entry for comparison later
    ; (so we can check if it has changed)
    lda sfxPQ, y
    pha
    lda sfxPQ_TTL, y
    pha

    ; track number of remaining entries in queue to scan
    ; (used as an iterator)
    lda #NSE_SFX_QUEUE_NUM_ENTRIES
    sta wSFX_setup_remaining_pq_entries

    ; looping sfx have a different insertion method
    lda wSFX_setup_sfx_duration
    sfxid_is_looping
    bmi @jmp_insertLoopingLoopTop

@insertLoopTop:
    ; A <- id of entry in pq
    lda sfxPQ.w, y
    beq @jmp_insertAtEmpty ; empty slot -- we can just insert here.

    ; check if existing sfx is higher-pri than proposed sound.
    cmp wSFX_setup_sfxid
    bcc @insert
    beq @insert

    ; higher-pri effect than proposed sound
    ; check if it would eclipse the proposed sound.

    ; A <- TTL for entry in pq
    lda sfxPQ_TTL.w, y
    cmp wSFX_setup_sfx_duration ; compare again proposed sound's TTL
    ; if eclipsed -- abort insertion.
    bcs @nextChannel_noinsert

    ; not eclipsed -- continue searching queue for somewhere to insert.

@insertLoopNext:
    iny
    dec wSFX_setup_remaining_pq_entries
    bne @insertLoopTop
    beq @jmp_nextChannel ; guaranteed

@rts1:
    rts

@jmp_insertLoopingLoopTop:
    jmp @insertLoopingLoopTop

@jmp_insertAtEmpty:
    jmp @insertAtEmpty

@insert:
    ; insert sfx at position Y in queue..
    ; we need to push the other queue elements down.

    ; first, scan for any sfx that would be eclipsed and remove them.
@evictEclipsed:
    ; store Y (index in queue for insertion)
    tya
    pha

    ; determine queue end
    clc
    adc wSFX_setup_remaining_pq_entries ; (-C)
    adc #$ff ; subtracts 1
    sta wSFX_setup_queue_end ; == queue end minus one

@evictEclipsedLoopTop:
    ; A <- TTL of proposed sfx
    lda wSFX_setup_sfx_duration

    ; compare against existing sound's TTL
    ; if existing sound is longer than proposed sound,
    ; then do not evict it.
    cmp sfxPQ_TTL, y
    bcc @evictEclipsedNext
    
    ; proposed sfx exceeds existing TTL
    ; check if sfx loops, in which case, stop trying to evict.
    lda sfxPQ, y
    sfxid_is_looping
    bmi @endEvictEclipse

    ; doesn't loop -- evict!

    ; store y (index in queue scanning for eclipsed sounds)
    tya
    pha

    ; swap up  until we reach the bottom of the queue, then replace
    ; bottom with empty.
@evictLoopTop:
    cpy wSFX_setup_queue_end
    beq +

    ; replace current with next
    lda sfxPQ+1, y
    sta sfxPQ, y
    lda sfxPQ_TTL+1, y
    sta sfxPQ_TTL, y

@evictLoopNext:
    iny
    bne @evictLoopTop ; guaranteed

@jmp_nextChannel:
    jmp @nextChannel
    
 +  ; reached end of queue -- replace entry with 0
    lda #$0
    sta sfxPQ, y
    sta sfxPQ_TTL, y

    ; mark that there is empty space (for later)
    sta wSFX_setup_pq_full

    ; since an entry was removed, we shouldn't increment y.
    ; (we need to check if the new entry is eclipsed as well.)
    pla
    tay
    jmp @evictEclipsedLoopTop

@evictEclipsedNext:

    ; restore y and increment
    pla
    tay 
    iny
    bpl @evictEclipsedLoopTop ; guaranteed

@endEvictEclipse:

    ; uncache Y
    pla
    tay

@insertNonLooping:
    ; this sound does not loop.
    ; check if existing pq sfx is looping -- if so, can't evict it.
    ; however, if the queue is not full, then it's safe to insert before it.
    lda wSFX_setup_pq_full
    beq +
        lda sfxPQ.w, y
        ; (note: guaranteed that sfxid != 0, otherwise we'd be at @insertAtEmpty)
        sfxid_is_looping
        bcc @nextChannel
+
    ; swap "proposed" sfx and sfx on pq
    tax 
    lda wSFX_setup_sfxid
    beq @insertAtEmpty ; if this is empty, handle separately.
    stx wSFX_setup_sfxid
    sta sfxPQ.w, y

    ; swap "proposed" sfx ttl and ttl on pq
    lda wSFX_setup_sfx_duration
    ldx sfxPQ_TTL.w, y
    sta sfxPQ_TTL.w, y
    stx wSFX_setup_sfx_duration

    ; recurse, to bump the rest of the sfx down
    ; -- unless we've reached the end of the queue.
    dec wSFX_setup_remaining_pq_entries
    bmi @nextChannel_checktopsfx

    iny
    bpl @insertNonLooping ; guaranteed

@nextChannel_noinsert:
    pla
    pla
    jmp @nextChannel

@insertAtEmpty:
    ; emplace sfx and duration at vacant slot.
    lda wSFX_setup_sfxid
    sta sfxPQ, y
    lda wSFX_setup_sfx_duration
    sta sfxPQ.w, y
    ; fallthrough @nextChannel_checktopsfx

@nextChannel_checktopsfx:
    ; X <- channel idx
    ; (we reused channel idx as a general register)
    ldx wChannelIdx

    ; determine if top entry has changed
    ; pull prev top id
    pla
    sta wChannelIdx

    ; pull prev top ttl
    pla 
    cmp sfxPQ_TTL, y
    beq @newtopprisfx

    lda wChannelIdx
    cmp sfxPQ, y
    bne @nextChannel

    ; restore channel idx
    stx wChannelIdx

@newtopprisfx:
    ; new sfx at top of pq
    ; mark this for later.
    lda bitIndexTable.w, x
    ora wSFX_setup_top_pri_has_changed
    sta wSFX_setup_top_pri_has_changed

@nextChannel:
    ; sfx base offset += 3
    ; (sfx store three bytes per channel)
    clc
    lda wSFX_setup_sfx_offset
    adc #$3
    sta wSFX_setup_sfx_offset ; (-C)

    ; sfx queue offset += sizeof(pq per channel)
    lda wSFX_setup_pq_offset
    adc #NSE_SFX_QUEUE_NUM_ENTRIES
    sta wSFX_setup_pq_offset

    ; next channel
    inc wChannelIdx
    lda wChannelIdx
    cmp #NUM_SFX_CHANS
    bpl +
    jmp @channelLoopTop
  +
    ; loop complete.

@replaceActiveSFX:
    ; TODO: loop through wSFX_setup_top_pri_has_changed
    ; begin playback for any marked sfx.
    ldx #$FF
    stx wChannelIdx
-   inc wChannelIdx
    asl wSFX_setup_top_pri_has_changed
    bcc +
    jsr nse_playTopSfx
  + ldx wChannelIdx
    cpx #NUM_SFX_CHANS
    bmi -

@rts:
    rts

@insertLoopingLoopTop:

    ; determine if we need to evict something to have room for this sfx.
    lda wSFX_setup_pq_full
    beq @insertLoopingNoEvict

    ; yes, an eviction is required.
    ; check if top sfx is non-looping
    lda sfxPQ.w, y
    sfxid_is_looping
    bpl @insertLoopingReplaceLooping
    ; fallthrough insertLoopingReplaceLooping

@insertLoopingReplaceLooping:
    ; if the pq is full of looping sfx, do not allow another looping sfx in.
    ; (sfx insertion fails.)
    jmp @nextChannel_noinsert

@nextInsertLoopingReplaceNonLooping:
    iny
    dec wSFX_setup_remaining_pq_entries
    beq @nextChannel_noinsert
@insertLoopingReplaceNonLooping:
    ; evict lowest-pri non-looping sfx.
    lda sfxPQ+1.w, y
    sfxid_is_looping
    bpl @nextInsertLoopingReplaceNonLooping

    ; we've found the first looping sfx, so
    ; replace the one before it.
    lda wSFX_setup_sfxid
    sta sfxPQ.w, y

    lda wSFX_setup_sfx_duration
    sta sfxPQ_TTL.w, y

    ; now percolate down so that looping sfx remain priority-sorted
@percolateDown:
    dec wSFX_setup_remaining_pq_entries
    beq @nextChannel_checktopsfx

    lda sfxPQ.w, y
    cmp sfxPQ+1.w, y
    bcs @nextChannel_checktopsfx
    ; swap
    tax 
    lda sfxPQ+1.w, y
    sta sfxPQ.w, y
    txa
    sta sfxPQ+1.w, y

    ldx sfxPQ_TTL+1.w, y
    lda sfxPQ_TTL.w, y
    sta sfxPQ_TTL+1.w, y
    txa
    sta sfxPQ_TTL.w, y

    iny
    jmp @percolateDown ; guaranteed

@jmp_insertNonLooping:
    jmp @insertNonLooping

@insertLoopingNoEvict:
    ; find first sfx with lower priority, then reuse
    ; inserion logic.
 -  lda wSFX_setup_sfxid
    cmp sfxPQ, y
    bcs @jmp_insertNonLooping
    iny
    bne - ; guaranteed

; preconditions:
;   wChannelIdx = current channel idx
nse_playTopSfx:
    ; TODO
    rts

nse_playMusic:
@setup_MUS_SILENCE:
@setup_MUS_PRELUDE:
    ; set song to song from table
    tay ; OPTIMIZE -- combine this with tay in playSFX at source dispatch (nse_playSound)
    lda nse_soundTable_lo, y
    sta wMacro@Song.w
    sta wSoundBankTempAddr2
    lda nse_soundTable_hi, y
    sta wMacro@Song+1.w
    sta wSoundBankTempAddr2+1

@initMusic:
    ; default values for music
    ldx #$01
    stx wMusTicksToNextRow_a1.w
    stx wMusRowsToNextFrame_a1.w
    ldx #SONG_MACRO_DATA_OFFSET
    stx wMacro@Song+2.w ; song start
    
    ; initialize music channel state
    ; loop(channels)
    ldy #NUM_CHANS
-   lda #$0
    sta wMusChannel_BaseVolume-1.w, y
    sta wMusChannel_ArpXY-1.w, y
    sta wMusChannel_portrate-1.w, y
    cpy #NSE_DPCM+1
    beq +
    cpy #NSE_NOISE+1
    beq +
    lda #$80
    sta wMusChannel_BaseDetune-1.w, y
    ; no need to set pitch; volume is 0.
  + dey
    bne -

    lda #$0
    sta wMusChannel_ReadNibble.w ; (paranoia)

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

@rts:
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
    .macro assert_songidx_valid
        lda wMacro@Song+2.w
        cmp #SONG_MACRO_DATA_OFFSET
        fail_if bcc
    .endm
    ASSERT assert_songidx_valid

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
    lda wMacro@Groove+1.w
    beq +
    .define MACRO_LOOP_ZERO
    .define MACRO_BYTE_ABSOLUTE wMacro@Groove-wMacro_start
    nse_nextMacroByte_inline_precalc_abaseaddr
+   bne ++
    ; default
    lda #$6
++
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
    bne -

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
    sta wNSE_current_channel_is_masked
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

    ; DUMMYOUT
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

    ; Y <- (input A) * 2
    ; (offset of phrase address from channel base)
    txa
    asl
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

.include "code/newSoundEngineDataTables.s"