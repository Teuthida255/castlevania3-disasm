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

    wMusGrooveIdx:
        db
    
    wMusGrooveSubIdx:
        db

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
    wMusChannel_BasePitch:
        dsb NUM_CHANS
    
    wMusChannel_BaseVolume:
        dsb NUM_CHANS
    
    ; ArpXY is state that modifies how arpeggios work.
    ; X and Y are added to certain arpeggio values.
    ; "X" is stored in the low nibble, "Y" in the high.
    wMusChannel_ArpXY:
        dsb NUM_CHANS

    ; some macros pack data in nibbles; this controls the.
    wMusChannel_ReadNibble:
        db
    ; end music state -----

    ; this could be re-calculated every instrument change, but
    ; it's helpful to cache this instead.
    wMusChannel_InstrTableAddr:
        dsw NUM_CHANS

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

        ; music macros
        wMacro@Sq1_Arp:
            dsb 3
        wMacro@Sq1_Detune:
            dsb 3
        wMacro@Sq1_Vol:
            dsb 3
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