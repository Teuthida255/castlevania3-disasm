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
    
    wMusChannel_BasePitch:
        dsb NUM_NON_CONDUCTOR_CHANS
    
    wMusChannel_BaseVolume:
        dsb NUM_NON_CONDUCTOR_CHANS

    ; this could be re-calculated every instrument change, but
    ; it's most efficient to cache.
    wMusChannel_InstrTableAddr:
        dsw NUM_NON_CONDUCTOR_CHANS

    ; macros
    .include "include/newSoundEngine/wMacros.s" namespace "wMacro"

.endif
.ends