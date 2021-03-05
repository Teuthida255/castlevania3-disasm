assert NSE_SIZEOF_MACRO == 3, "must match below."
.macro macro_def
    @lo:
        db
    @hi:
        db
    @offset:
        db
.endm

; sound macro fields
start:

Song:
    macro_def

; phrase macros ---------------------------------
phrases:

Sq1_Phrase:
    macro_def
Sq2_Phrase:
    macro_def
Tri_Phrase:
    macro_def
Noise_Phrase:
    macro_def
DPCM_Phrase:
    macro_def
Sq3_Phrase:
    macro_def
Sq4_Phrase:
    macro_def
Conductor_Phrase:
    macro_def

; music macros
Sq1_Base:
Sq1_Arp:
    macro_def
Sq1_Detune:
    macro_def
Sq1_Vol:
    macro_def
Sq1_Duty:
    macro_def
Sq1_End:

Sq2_Base:
Sq2_Arp:
    macro_def
Sq2_Detune:
    macro_def
Sq2_Vol:
    macro_def
Sq2_Duty:
    macro_def
Sq2_End:

Tri_Base:
Tri_Arp:
    macro_def
Tri_Detune:
    macro_def
Tri_End:

Noise_Base:
Noise_Arp: ; (also controls noise mode)
    macro_def
Noise_Vol:
    macro_def
Noise_End:

Sq3_Base:
Sq3_Arp:
    macro_def
Sq3_Detune:
    macro_def
Sq3_Vol:
    macro_def
Sq3_Duty:
    macro_def
Sq3_End:

Sq4_Base:
Sq4_Arp:
    macro_def
Sq4_Detune:
    macro_def
Sq4_Vol:
    macro_def
Sq4_Duty:
    macro_def
Sq4_End: