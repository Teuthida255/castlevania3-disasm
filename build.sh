#!/bin/bash
set -e
set -x
#export ROMHACK=
#make nes
#mv castlevania3build.nes castlevania3.nes
export ROMHACK=1
make nes
python3 tools/fceux_symbols.py