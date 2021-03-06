
silenceAllSoundChannels:
.ifdef SOUND_ENGINE
	lda #PRG_ROM_SWITCH|:nse_silenceAllSoundChannels
	jsr saveAndSetNewLowerBank
	jsr nse_silenceAllSoundChannels
.else
	lda #PRG_ROM_SWITCH|:b18_silenceAllSoundChannels
	jsr saveAndSetNewLowerBank
	jsr b18_silenceAllSoundChannels
.endif
	lda wPrgBankBkup_8000
	jmp setAndSaveLowerBank


setAndSaveLowerBank18h:
	lda #SOUND_ENGINE_BANK
	jmp setAndSaveLowerBank


playDMCSound:
	pha
	lda #PRG_ROM_SWITCH|:b18_playDMCSound
	jsr setAndSaveLowerBank
	pla
	jmp b18_playDMCSound


getCurrInstrument1stDataByte:
	lda wInstrumentDataBanks.w, x
	jsr setAndSaveLowerBank
	lda (wTempCurrInstrumentDataAddr), y

	pha
	lda #SOUND_ENGINE_BANK
	jsr setAndSaveLowerBank
	pla

	rts


processNextSoundByteAltAtInstrumentsDataBank:
	lda wInstrumentDataBanks.w, x
	jsr setAndSaveLowerBank
	jmp b18_soundCommon.processNextSoundByteAlt


func_1f_01ce:
B31_01ce:		pha				; 48 
B31_01cf:		lda #PRG_ROM_SWITCH|:func_18_0b91		; a9 98
B31_01d1:		jsr setAndSaveLowerBank		; 20 e6 e2
B31_01d4:		pla				; 68 
B31_01d5:		jsr func_18_0b91		; 20 91 8b
B31_01d8:		lda wInstrumentDataBanks.w, x	; bd 95 01
B31_01db:		jmp setAndSaveLowerBank		; 4c e6 e2


func_1f_01de:
	jsr_8000Func func_18_0b55
B31_01e6:		lda wInstrumentDataBanks.w, x	; bd 95 01
B31_01e9:		jmp setAndSaveLowerBank		; 4c e6 e2


processNextEnvelopeByte:
	jsr_8000Func b18_processNextEnvelopeByte
	lda wInstrumentDataBanks.w, x
	jmp setAndSaveLowerBank


processNextSoundByte:
	pha
	lda #PRG_ROM_SWITCH|:b18_processNextSoundByte
	jsr setAndSaveLowerBank
	pla
	jmp b18_processNextSoundByte


processNextSoundByteMain:
	lda #PRG_ROM_SWITCH|:b18_processNextSoundByteMain
	jsr setAndSaveLowerBank
	jmp b18_processNextSoundByteMain


func_1f_020c:
	jsr_8000Func func_18_0986
B31_0214:		ldx wCurrInstrumentIdx			; a6 ee
B31_0216:		lda wInstrumentDataBanks.w, x	; bd 95 01
B31_0219:		jmp setAndSaveLowerBank		; 4c e6 e2


; unused?
setAndSaveInstrumentsDataBank:
	lda wInstrumentDataBanks.w, x
	jmp setAndSaveLowerBank


; unused?
setLowerBankTo18h:
	lda #PRG_ROM_SWITCH|SOUND_ENGINE_BANK
	jmp setAndSaveLowerBank


initSound:
	lda #$ff
	sta wIsExecutingSoundFunc

	lda wPrgBank_8000
	sta wPrgBankBkup2_8000
.ifdef SOUND_ENGINE
	jsr_8000Func nse_initSound
.else
	jsr_8000Func b18_initSound
.endif
	jmp soundFunc_setNotExecuting


updateSoundIfNotExecutingSoundFunc:
	lda wIsExecutingSoundFunc
	bne +

	lda wPrgBank_8000
	pha
.ifdef SOUND_ENGINE
	jsr_8000Func nse_updateSound
.else
	jsr_8000Func b18_updateSound
.endif
	pla
	jmp setAndSaveLowerBank

+	rts


updateSound:
	lda #$ff
	sta wIsExecutingSoundFunc
.ifdef SOUND_ENGINE
	jsr_8000Func nse_updateSound
.else
	jsr_8000Func b18_updateSound
.endif
	lda #$00
	sta wIsExecutingSoundFunc
	rts


playSound:
	pha

	lda #$ff
	sta wIsExecutingSoundFunc

	lda wPrgBank_8000
	sta wPrgBankBkup2_8000
.ifdef SOUND_ENGINE
	lda #PRG_ROM_SWITCH|:nse_playSound
	jsr setAndSaveLowerBank

	pla
	jsr nse_playSound
.else
	lda #PRG_ROM_SWITCH|:b18_playSound
	jsr setAndSaveLowerBank

	pla
	.ifdef NO_SOUND
		nop
		nop
		nop
	.else
		jsr b18_playSound
	.endif
.endif

soundFunc_setNotExecuting:
	lda #$00
	sta wIsExecutingSoundFunc
	lda wPrgBankBkup2_8000
	jmp setAndSaveLowerBank