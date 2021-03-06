.print "Compiling...\n"

.include "include/rominfo.s"
.include "include/constants.s"
.include "include/macros.s"
.include "include/scriptMacros.s"
.include "include/hardware.s"
.include "include/structs.s"
.include "include/wram.s"

.bank $00 slot 1
.org 0

    .db $80
    .include "code/bank00.s"

.bank $01 slot 2
.org 0

    .include "code/bank01.s"

.bank $02 slot 1
.org 0

    .db $82
    .include "code/bank02.s"
    .include "code/irqFuncs_b02.s"

.bank $03 slot 2
.org 0

    .include "code/irqFuncs_b03.s"
    .include "code/gameState9_introCutscene.s"
    .include "code/bank03.s"

.bank $04 slot 1
.org 0

    .db $84
    .include "code/bank04.s"

.bank $05 slot 2
.org 0

    .include "code/bank05.s"

.bank $06 slot 1
.org 0

    .db $86
    .include "code/bank06.s"

.bank $07 slot 3
.org 0

    .include "data/commonDPCMdata.s"
    .include "data/b7_dpcmData.s"

.bank $08 slot 1
.org 0

    .db $88
    .include "code/soundCommon.s" namespace "b08_soundCommon"
    .include "data/soundData_b08.s"

.bank $09 slot 2
.org 0

    .include "data/soundData_b09.s"
    .include "code/bank09.s"

.bank $0a slot 1
.org 0

    .db $8a
    .include "code/soundCommon.s" namespace "b0a_soundCommon"
    .include "data/soundData_b0a.s"

.bank $0b slot 2
.org 0

    .include "data/soundData_b0b.s"
    .include "code/bank0b.s"

.bank $0c slot 1
.org 0

    .db $8c
    .include "data/roomMetatilesPalettesData_b0c.s"

.bank $0d slot 2
.org 0

    .include "data/roomMetatilesPalettesData_b0d.s"
    .include "code/bank0d.s"

.bank $0e slot 1
.org 0

    .db $8e
    .include "data/roomMetatilesPalettesData_b0e.s"

.bank $0f slot 2
.org 0

    .include "data/roomMetatilesPalettesData_b0f.s"
    .include "code/bank0f.s"
    .include "data/stairsLocationsData.s"

.bank $10 slot 1
.org 0

    .db $90
    .include "data/roomMetatilesPalettesData_b10.s"

.bank $11 slot 2
.org 0

    .include "data/roomMetatilesPalettesData_b11.s"
    .include "data/staticLayouts_b11.s"
    .include "code/bank11.s"

.bank $12 slot 1
.org 0

    .db $92
    .include "code/bank12.s"

.bank $13 slot 2
.org 0

    .include "code/bank13.s"

.bank $14 slot 1
.org 0

    .db $94
    .include "code/bank14.s"
    .include "data/roomEntities_b14.s"

.bank $15 slot 2
.org 0

    .include "data/roomEntities_b15.s"
    .include "data/enemyMetadata.s"
    ; todo: possibly contains junk at the end
    .include "data/luminaryMetadata.s"
    .include "code/gameStateCD_ending.s"
    .include "data/staticLayouts_b15.s"

.bank $16 slot 1
.org 0

    .db $96
    .include "code/entityPhaseFuncs_b16.s"

.bank $17 slot 2
.org 0

    .include "code/entityPhaseFuncs_b17.s"
    .include "data/entityScripts.s"
    .include "code/bank17.s"
    .include "data/entityPhaseFuncsAndScripts.s"

.bank $18 slot 1
.org 0

    .db $98
    .include "code/soundCommon.s" namespace "b18_soundCommon"
    .include "code/soundEngine.s"
    .include "data/soundPointers.s"
    .include "data/soundData_b18.s"
    .include "data/soundEnvelopeData_b18.s"

.bank $19 slot 2
.org 0

    .include "data/soundEnvelopeData_b19.s"
    .include "data/dpcmSpecData.s"
    .include "code/gameStateF_soundMode.s"
    .include "code/bank19.s"

.bank $1a slot 1
.org 0

    .db $9a
    .include "code/updateEntityOam.s"
    .include "data/oamSpecData_1a.s"

.bank $1b slot 2
.org 0

    .include "data/oamSpecData_1b.s"
    .include "code/bank1b.s"

.bank $1c slot 1
.org 0

    .db $9c
    .include "code/playerStateProcessing_b1c.s"

.bank $1d slot 2
.org 0

    ; todo: possibly contains junk at the end
    .include "code/playerStateProcessing_b1d.s"

.bank $1e slot 3
.org 0

    .include "data/commonDPCMdata.s"
    .include "code/bank1e.s"

.ifdef IS_EXTENDED_ROM

    .ifdef SOUND_ENGINE
        .bank $20 slot 1
        .org 0

        .include "code/newSoundEngine.s"
        .include "code/newSoundEngineData.s"
    .endif

    .bank $7f slot 4
.else
    .bank $1f slot 4
.endif
.org 0

    .db $9e
    .include "code/bank1f.s"
