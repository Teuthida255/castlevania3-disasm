DEFINES = 

ifdef ROMHACK
	DEFINES += -D IS_EXTENDED_ROM \
		-D INSTANT_CHAR_SWAP \
		-D IMPROVED_CONTROLS_TEST \
		-D SEPARATED_LAMP_GFX \
		-D EXTENDED_RAM \
		-D WEAPON_SWAPPING \
		-D FASTER_STAIR_CLIMB \
		-D MID_STAGE_PALETTE_SWAP \
		-D SOUND_ENGINE \
		-D INSERT_SOUND \
		-D SCREEN_SHAKE \
		-D NSE_NO_FIXED_MACROS \
		-D DEBUG
endif

ifdef NSE_NO_PULSE_1
	DEFINES += -D NSE_NO_PULSE_1
endif

ifdef NSE_NO_PULSE_2
	DEFINES += -D NSE_NO_PULSE_2
endif

ifdef NSE_NO_TRI
	DEFINES += -D NSE_NO_TRI
endif

ifdef NSE_NO_NOISE
	DEFINES += -D NSE_NO_NOISE
endif

ifdef NSE_NO_DPCM
	DEFINES += -D NSE_NO_DPCM
endif

ifdef NSE_NO_PULSE_3
	DEFINES += -D NSE_NO_PULSE_3
endif

ifdef NSE_NO_PULSE_4
	DEFINES += -D NSE_NO_PULSE_4
endif

castlevania3.bin: code/* include/* data/* game.s Makefile

# -I: include directory.
# -i: include list definitions (required for line numbers)
#   -i temporarily removed because it causes wla-6502 to error for unknown reasons.
	wla-6502 ${DEFINES} -I . -o game.o game.s

# -s: write GMB/SNES symbol file
# -S: write WLA symbol file
# -A: include address-to-line mapping data in WLA symbol file (not in practical use -- see above)
	wlalink -S -A linkfile castlevania3.bin
	rm game.o

nes: castlevania3.bin tools/*.py
	python3 ${PYARGS} tools/buildNes.py ${DEFINES}

clean:
	rm -f build/castlevania3build.nes castlevania3.bin