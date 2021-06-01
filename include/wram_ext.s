;=========================================================================================
; Bank 1
;=========================================================================================

.ramsection "RAM 1" bank 1 slot 5
.ifdef WEAPON_SWAPPING
    wTrevorNumSubweapons: ; $6000
        .db

    wTrevorSubweapons: ; $6000
        dsb $10

    wP2NumSubweapons: ; $6010
        .db

    wP2Subweapons: ; $6010
        dsb $10

    wNumWeaponsOffset: ; $6020
        db

    wCurrSubweaponOffset: ; $6021
        db
.endif

.ifdef MID_STAGE_PALETTE_SWAP
    wBackupInternalBGPalettes: ; $6022
        dsb 9

    wDimmerInternalBGPalettes: ; $602b
        dsb 9

    wBrighterInternalBGPalettes: ; $6034
        dsb 9
.endif

.ifdef SCREEN_SHAKE
    wOrigScreenShakeX: ; $603d
        db

    wIsShaking: ; $603e
        db
.endif

.ifdef SOUND_ENGINE
    ; "_a1" suffix means stored value is 1 greater than semantic value

    ; if (semantic) this is 0, then the row will advance on the next update.
    wMusTicksToNextRow_a1:
        db

    ; if (semantic) this is 0, then the frame will advance on the next row-update.
    wMusRowsToNextFrame_a1:
        db

    ; ---------------------------------------------------------
    ; music per-channel state
    ; ---------------------------------------------------------
    ; if (semantic) this is 0, will advance on next row-update.
    wMusChannel_RowsToNextCommand_a1:
        dsb NUM_CHANS
    
    ; music state ---------
    ; pitch is a 7-bit value representing a semitone value.
    ; DPCM: hijacked as gv8
    wMusChannel_BasePitch:
        dsb NUM_CHANS
    
    ; value between 0 and F for square and noise channels,
    ; high nibble stores "echo volume," which can be swapped in.
    ; Triangle: nonzero if on, $0 otherwise.
    ; DPCM: hijacked by triangle
    wMusChannel_BaseVolume:
        dsb NUM_CHANS
    
    ; signed value centred at 80, indicating detune for channel
    ; DPCM: (available for use)
    ; noise: stores sfx mask
    wMusChannel_BaseDetune:
        dsb NUM_CHANS

    ; tracks the total detune incurred by the macro.
    ; reset to $00 on each note.
    ; two-byte signed value.
    wMusChannel_DetuneAccumulator_Lo:
        ; centred at $80
        dsb NUM_CHANS

    wMusChannel_DetuneAccumulator_Hi:
        ; centred at $80
        dsb NUM_CHANS

    ; ArpXY is state that modifies how arpeggios work.
    ; X and Y are added to certain arpeggio values.
    ; "X" is stored in the low nibble, "Y" in the high.
    ; DPCM: stores nibble parity instead
    wMusChannel_ArpXY:
        dsb NUM_CHANS

    ; portamento rate. If this is non-zero, arpeggios are disabled.
    wMusChannel_portrate:
        dsb NUM_CHANS

    ; end music state ----------

    ; sfx priority queues
    ; 1 pq per (sfx) channel
    ; N sfx per queue
    ; stores ID of sfx
    sfxPQ:
        dsb NUM_SFX_CHANS * NSE_SFX_QUEUE_NUM_ENTRIES

    ; queue entry -- "time-to-live" (remaining duration
    sfxPQ_TTL:
        dsb NUM_SFX_CHANS * NSE_SFX_QUEUE_NUM_ENTRIES

    ; cache values -------------

    ; this could be re-calculated every instrument change, but
    ; it's helpful to cache this instead.
    wMusChannel_CachedChannelTableAddr:
        dsw NUM_CHANS

    ; hardware register cache -- write to these during the mixing logic
    ; (runs at 60 Hz), then send these all at once to the hardware
    ; registers after mixing, while interrupts are disabled, to prevent
    ; any audio glitches. (Thread safety!)
    ; The order of these allows certain optimizations.
    wMix_CacheReg_Sq1_Vol:
        db
    wMix_CacheReg_Sq1_Lo:
        db
    wMix_CacheReg_Sq1_Hi:
        db

    wMix_CacheReg_Sq2_Vol:
        db
    wMix_CacheReg_Sq2_Lo:
        db
    wMix_CacheReg_Sq2_Hi:
        db

    wMix_CacheReg_Tri_Vol:
        db
    wMix_CacheReg_Tri_Lo:
        db
    wMix_CacheReg_Tri_Hi:
        db
    
    wMix_CacheReg_Noise_Vol:
        db
    wMix_CacheReg_Noise_Lo:
        db
    wNSE_genVar9w:
        db

    wNSE_genVar10w:
        db
    wNSE_genVar11w:
        db
    wNSE_genVar12w:
        db

    wMix_CacheReg_Sq3_Vol:
        db
    wMix_CacheReg_Sq3_Lo:
        db
    wMix_CacheReg_Sq3_Hi:
        db

    wMix_CacheReg_Sq4_Vol:
        db
    wMix_CacheReg_Sq4_Lo:
        db
    wMix_CacheReg_Sq4_Hi:
        db

    ; end cache values ----------

    ; macros
        ;assert NSE_SIZEOF_MACRO == 3, "must match below."
        ;.macro macro_def
        ;    @@lo:
        ;        db
        ;    @@hi:
        ;        db
        ;    @@offset:
        ;        db
        ;.endm

        ; sound macro fields
        wMacro@Song:
            dsb 3

        ; phrase macros ---------------------------------        
        wMacro@Sq1_Phrase:
            dsb 3
        wMacro@Sq2_Phrase:
            dsb 3
        wMacro@Tri_Phrase:
            dsb 3
        wMacro@Noise_Phrase:
            dsb 3
        wMacro@DPCM_Phrase:
            dsb 3
        wMacro@Sq3_Phrase:
            dsb 3
        wMacro@Sq4_Phrase:
            dsb 3

        ; groove
        ; (always loops to zero, doesn't store loop point)
        wMacro@Groove:
            dsb 3

        ; channel macros
        ; (these always loop to zero, and don't store a loop point)
        wMacro@Sq1_Vib:
            dsb 3
        wMacro@Sq2_Vib:
            dsb 3
        wMacro@Tri_Vib:
            dsb 3
        wMacro@Sq3_Vib:
            dsb 3
        wMacro@Sq4_Vib:
            dsb 3

        ; music macros
        
        ; Arp macros (on all channels) are co-opted to store portamento state if portamento is enabled.
        ; portamento state: 2 bytes of frequency, 1 byte of rate.
        wMacro@Sq1_Arp:
            dsb 3
        wMacro@Sq1_Detune:
            dsb 3
        wMacro@Sq1_Vol:
            dsb 3
        ; duty macro offset (on all channels) is co-opted to store duty cycle if
        ; no duty macro is specified (i.e. if addr hi == 0).
        ; duty cycle is stored as:
        ; 0 -> %00110000
        ; 1 -> %01110000
        ; 2 -> %10110000
        ; 3 -> %11110000
        wMacro@Sq1_Duty:
            dsb 3

        wMacro@Sq2_Arp:
            dsb 3
        wMacro@Sq2_Detune:
            dsb 3
        wMacro@Sq2_Vol:
            dsb 3
        wMacro@Sq2_Duty:
            dsb 3

        wMacro@Tri_Arp:
            dsb 3
        wMacro@Tri_Detune:
            dsb 3
        wMacro@Tri_Length: ; is treated as Tri_State (if odd)
            dsb 3

        wMacro@Noise_Arp: ; (also controls noise mode)
            dsb 3
        wMacro@Noise_Vol:
            dsb 3

        wMacro@Sq3_Arp:
            dsb 3
        wMacro@Sq3_Detune:
            dsb 3
        wMacro@Sq3_Vol:
            dsb 3
        wMacro@Sq3_Duty:
            dsb 3

        wMacro@Sq4_Arp:
            dsb 3
        wMacro@Sq4_Detune:
            dsb 3
        wMacro@Sq4_Vol:
            dsb 3
        wMacro@Sq4_Duty:
            dsb 3
.endif
.ends

.define wMix_CacheReg_start wMix_CacheReg_Sq1_Vol

.define wMacro_start wMacro@Song
.define wMacro_phrase wMacro@Sq1_Phrase
.define wMacro_Sq1_Base wMacro@Sq1_Arp
.define wMacro_Sq1_End wMacro@Sq2_Arp
.define wMacro_Sq2_Base wMacro@Sq2_Arp
.define wMacro_Sq2_End wMacro@Tri_Arp
.define wMacro_Tri_Base wMacro@Tri_Arp
.define wMacro_Tri_End wMacro@Noise_Arp
.define wMacro_Noise_Base wMacro@Noise_Arp
.define wMacro_Noise_End wMacro@Sq3_Arp
.define wMacro_Sq3_Base wMacro@Sq3_Arp
.define wMacro_Sq3_End wMacro@Sq4_Arp
.define wMacro_Sq4_Base wMacro@Sq4_Arp
.define wMacro_Sq4_End wMacro@Sq4_Duty+3
.define wMacro_Chan_Base wMacro@Groove
.define wMacro_end wMacro_Sq4_End

; bit 6 stores previous value of triangle unmute
; bit 7 used to indicate pending mute
.define wMusTri_Prev wMusChannel_BaseVolume+NSE_DPCM

; some macros pack data in nibbles; this controls that.
.define wMusChannel_ReadNibble wMusChannel_ArpXY+NSE_DPCM

.define wSFXChannelActive wMusChannel_BaseDetune+NSE_NOISE

.define wNSE_genVar8w wMusChannel_BasePitch+NSE_DPCM
.define wNSE_genVar9w wMusChannel_BasePitch+NSE_DPCM