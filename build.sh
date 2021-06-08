#!/bin/bash
set -e
set -x
#export ROMHACK=
#make nes
#mv castlevania3build.nes castlevania3.nes
export ROMHACK=1

# mute tracks (for debugging)
if [ ! -z CV3_DEBUG ]
then
  export NSE_NO_PULSE_2=1
  export NSE_NO_TRI=1
  export NSE_NO_NOISE=1
  export NSE_NO_DPCM=1
  export NSE_NO_PULSE_3=1
  export NSE_NO_PULSE_4=1
fi

make nes
python3 tools/fceux_symbols.py