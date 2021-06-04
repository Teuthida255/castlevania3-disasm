## Compiling
* Requires [wla-dx](https://github.com/vhelin/wla-dx) and [python3](https://www.python.org/).
* `make nes` will build the ROM in the `build/` directory, it assumes the directory `original` exists, with CHR ROM, `OR.chr` inside. ([NesExtract](https://github.com/X-death25/Nes-Extract) can be used to extract the chr from a ROM)
* To compile the romhack version, define `export ROMHACK=1` before running `make nes`.
* To get fceux debug symbols, build using `bash ./build.sh` instead.

## Misc
* Helper scripts:
    * assume the PRG ROM exists at `original/OR.bin`, though this is just for data extraction atm
    * require the `pypng` package to be installed. `python3 -m pip install pypng`

## Structure
* Disassembled PRG ROM exists in `code/`
* `include` is RAM defines and some other helper files like `constants.s` and `macros.s`
* `json` is intermediate data, created by scripts for use in other scripts
* `tools` has the scripts for data extraction, tilemap generating, and in the future, everything else we need to speed up development
* `lua` contains scripts for debugging when using FCEUX. (First run the fceux_symbols python script in tools, then run `fceux --loadlua nse.lua build/castlevania3build.nes`)

## Development
* When adding new opcodes or adjusting existing ones, make sure to update the following:
  * code/newSoundEngineCommands.s
  * tools/ftToData.py
  * lua/nse_opcodes.lua (function 'display_pattern')