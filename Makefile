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
		-D SCREEN_SHAKE
endif

castlevania3.bin: code/* include/* data/* game.s Makefile
	wla-6502 ${DEFINES} -I . -o game.o game.s
	wlalink -s linkfile castlevania3.bin
	rm game.o

nes: castlevania3.bin
	python3 tools/buildNes.py ${DEFINES}
