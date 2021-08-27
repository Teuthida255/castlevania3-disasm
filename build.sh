#!/bin/bash
set -e

USAGE="Usage: $0 config"

defines=""

if [ $# -lt 1 ]
then
  echo "build configuration required."
  echo "$USAGE"
  exit 5
fi

config=$1

if [ $config == "cv3" ]
then
  true
elif [ $config == "sonia" ]
then
  DEFINES="$DEFINES -D IS_EXTENDED_ROM \
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
		-D DEBUG"
else
  echo "'config' must be one of 'cv3' or 'sonia'"
  echo "$USAGE"
  exit 5
fi

set -x

wla-6502 ${DEFINES} -I . -o game.o game.s
wlalink -S -A linkfile castlevania3.bin
python3 ${PYARGS} tools/buildNes.py ${DEFINES}
python3 tools/fceux_symbols.py

set +x
echo "game built at ./build/castlevania3build.nes"