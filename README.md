## Compiling
* Requires [wla-dx](https://github.com/vhelin/wla-dx) and [python3](https://www.python.org/).
* `build.sh` will build the ROM in the `build/` directory, it assumes the directory `original` exists, with CHR ROM, `OR.chr` inside. ([NesExtract](https://github.com/X-death25/Nes-Extract) can be used to extract the chr from a ROM)
* Run `./build.sh cv3` to produce the original cv3 game, and `./build.sh sonia` to produce the sonia sound engine hacked version.
* If building on Windows, [git bash](https://git-scm.com/downloads) is recommended.

## Notation
* `pitch` refers to a note index, e.g. 0 is A0, 11 is G#-1, etc.
* `frequency` refers to a PSU timer value (which is actually a measure of period, but the notation is stuck.)
* `reverse-signed` means that the sign bit indicates positive instead of negative, e.g. `0x80` is 0, `0x81` is 1, and `0x7f` is -1.
* the variable suffix `_a1` (in any language) means "plus one". For example, the variable `chan_idx_a1` refers to a value of *one plus the channel idx*. Thus, `chan_idx_a1 = 3` means channel idx is 2 (i.e. triangle wave).
  * This is useful for certain performance benefits in 6502. It is also useful in Lua because Lua is 1-indexed.
  * The downside is, the variables `chan_idx` and `chan_idx_a1` exist as a union at the same point in memory, and it can sometimes be difficult to tell which one is active when reading the code.

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

## Debugging
* In FCEUX using Lua: `fceux --loadlua nse.lua build/castlevania3build.nes`
* In VSCode (via `fceux`):
  * ensure luarocks is configured to install Lua 5.1-compatible libraries
  * `luarocks install luasocket`
  * `luarocks install dkjson`
  * If on Linux, please ensure fceux compiled with Lua shared library support. `LUA_CFLAGS` should include `-DLUA_USE_DLOPEN -DDLUA_USE_POSIX`
  * Press F5 in vscode

## Misc
* Helper scripts:
    * assume the PRG ROM exists at `original/OR.bin`, though this is just for data extraction atm
    * require the `pypng` package to be installed. `python3 -m pip install pypng`