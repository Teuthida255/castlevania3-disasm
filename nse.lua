-- Displays debug info for sound engine.
--
-- Usage:
-- 
--   fceux -lua nse.lua build/castlevania3build.nes
--
-- Parameters:
-- Set environment variable CV3_DEBUG_LUA_ARGS to pass args, or use fceux's script window.
--
-- args: [--solo-<CHNAME>] [--mute-<CHNAME>] [--render]
--
-- In-Game Usage:
--
-- Press save-state button during emulation (default: 'I') to get a snapshot
-- of the sound engine state printed in fceux's script window.
-- Press select to switch selected channel for displaying in render window (requires --render).

-- required for 'require' to work correctly
package.path = "?.lua;lua/?.lua"
if os.getenv("LUA_PATH") then
    package.path = package.path .. ";" .. os.getenv("LUA_PATH")
    emu.print(package.path)
end
if os.getenv("LUA_CPATH") then
    package.cpath = package.cpath .. ";" .. os.getenv("LUA_PATH")
end

--------------------------------------------------------------------------------
-- printing functions
-- (used by imports)

function print_fceux_reset()
    g_line = 0
    g_frame_idx = g_frame_idx + 1
    if g_frame_idx == 1 then
        emu.print("---------------------------------")
    end
end

function print_fceux(s, onscreen)
    if g_print_emu_only then
        emu.print(s)
        io.write(tostring(s) .. "\n")
        return
    end
    if onscreen or onscreen == nil then
        gui.text(4,12 + g_line * 8, s)
        g_line = g_line + 1
        for i in s:gfind("\n") do
            g_line = g_line + 1
        end
    end
end

--------------------------------------------------------------------------------
-- imports
-- (order is important.)

-- lua utilities (fceux-agnostic).
require("util")

-- data / debug symbols
require("symbols_data")

-- global variable definitions
require("globals")

-- adjusts some globals
require("parse_clargs")

-- functions for reading/parsing domain-specific information from RAM.
require("ram_parser")

-- watch assertions defined symbollically
require("luasrt")

-- functions for parsing pharse patterns
require("nse_opcodes")

require("verify_ticks")

-- this is printed to the fceux lua script window (to verify the script works)
emu.print("starting...")

-- required for debugging
if os.getenv("NSE_DEBUG_VSCODE") then
    emu.print("nse debug vscode")
    local json = require 'dkjson'
    local debuggee = require 'vscode-debuggee'
    local startResult, breakerType = debuggee.start(json)
    print('debuggee start ->', startResult, breakerType)
end


--------------------------------------------------------------------------------
-- main routines

-- read joystick, update variables
function handle_input()
    local input = joypad.readimmediate(1)
    if input == nil then
        return
    end
    if input["select"] then
        if not g_select_high then
            g_channel = (g_channel + 1) % CHAN_COUNT
        end
        g_select_high = true
    else
        g_select_high = false
    end
end

-- display main output
function display()
    -- bankswap info
    print_fceux("mmc5 prg:" .. tostring(mmc5_bytes[0x5100]))
    -- song macro
    local song_macro = g_symbols_ram["wMacro@Song"]
    print_fceux("song-macro: " .. macro_to_string_brief(song_macro));

    -- groove info
    local ticks_to_next_row = ram_read_byte_by_name("wMusTicksToNextRow_a1")
    local groove_macro = g_symbols_ram["wMacro@Groove"]
    print_fceux("groove-macro: " .. macro_to_string_brief(groove_macro, true));
    print_fceux(HX(ticks_to_next_row) .. " |" .. macro_tickertape(groove_macro, 7, true), true)

    -- current channel
    local channel_idx = ram_read_byte_by_name("wChannelIdx")
    local channel_idx_str = "channel-idx: " .. tostring(channel_idx) .. "  "
    if channel_idx == 0 then
        channel_idx_str = channel_idx_str .. "z:" .. CHANNEL_NAMES[1]
    elseif channel_idx == #CHANNEL_NAMES then
        channel_idx_str = channel_idx_str .. "a1:" .. CHANNEL_NAMES[channel_idx]
    elseif channel_idx < #CHANNEL_NAMES then
        channel_idx_str = channel_idx_str .. "a1:" .. CHANNEL_NAMES[channel_idx] .. "/z:" .. CHANNEL_NAMES[channel_idx + 1]
    end
    print_fceux(channel_idx_str)

    -- track number
    -- TODO: identify track number.
    local track_number = 1

    local soundinfo = sound.get()
    
    -- each channel
    for chan_idx_a1 = 1, CHAN_COUNT do
        local channel_data = tracks[track_number].channels[chan_idx_a1]
        if DISPLAY_CHANNELS[chan_idx_a1] then
            -- separator
            print_fceux("---", false)

            -- display channel phrase
            local channel_name = tostring(CHANNEL_NAMES[chan_idx_a1])
            local phrase_macro_addr = g_symbols_ram["wMacro@" .. channel_name .. "_Phrase"]
            local onscreen = g_render and (chan_idx_a1 == g_channel + 1)
            print_fceux("channel " .. channel_name .. " phrase " .. macro_to_string_brief(phrase_macro_addr), onscreen)
            print_fceux(macro_tickertape(phrase_macro_addr, 10), onscreen)

            -- display channel stats
            if DISPLAY_CHANNEL_VARS then
                local s = display_stat("t", "wMusChannel_RowsToNextCommand_a1", chan_idx_a1) .. " "
                if channel_name ~= "DPCM" then
                    s = s .. display_stat("p", "wMusChannel_BasePitch", chan_idx_a1) .. " "
                    s = s .. display_stat("v", "wMusChannel_BaseVolume", chan_idx_a1) .. " "
                    s = s .. display_stat("xy", "wMusChannel_ArpXY", chan_idx_a1) .. " "
                    s = s .. display_stat("port", "wMusChannel_portrate", chan_idx_a1) .. " "
                    if channel_name ~= "Noise" then
                        s = s .. display_stat("det", "wMusChannel_BaseDetune", chan_idx_a1) .. " "
                    end
                end
                print_fceux(s, onscreen)
            end

            if TRACK_CHANNEL_INSTRUMENT then
                local instr_idx = g_instr_idx_by_channel[chan_idx_a1]
                if instr_idx >= 0 then
                    local s = "instr " .. HX(instr_idx, 1)
                    if instr_idx >= 0 and instr_idx < 0x10 and channel_data[instr_idx + 1] then
                        s = s .. ' "' .. channel_data[instr_idx + 1].name .. '"'
                    end
                    print_fceux(s, onscreen)
                else
                    print_fceux("instr not set", onscreen)
                end
            end

            -- display channel instrument
            if DISPLAY_CHANNEL_INSTRUMENT then
                local s = interpret_channel_instrument(chan_idx_a1)
                print_fceux(s, onscreen)
            end

            -- display cached channel registers
            if DISPLAY_CACHED_REGISTERS then
                local s = "CACHE. "
                for register_idx, register_name in ipairs(CHANNEL_CACHE_REGISTERS[chan_idx_a1]) do
                    local register_value = ram_read_byte_by_name("wMix_CacheReg_" .. channel_name .. "_" .. register_name)
                    s = s .. register_name:gsub(channel_name .. "_", "") .. ":" .. HX(register_value) .. " "
                end
                print_fceux(s, onscreen)
            end

            if DISPLAY_INTERPRETED_CACHED_REGISTERS then
                local s = interpret_cached_registers(chan_idx_a1)
                if s ~= nil then
                    print_fceux("CACHE. " .. s, onscreen)
                end
            end

            -- display channel registers
            if DISPLAY_REGISTERS then
                local reginfo = CHANNEL_REGISTERS[chan_idx_a1]
                local chip = reginfo.chip
                local chipinstr = reginfo.chipinstr
                if chip ~= nil and soundinfo[chip] ~= nil and soundinfo[chip][chipinstr] then
                    local s = "REG. " .. interpret_registers(chan_idx_a1, soundinfo[chip][chipinstr])
                    local instrinfo = 
                    print_fceux(s, onscreen)
                end
            end

            -- display channel macros
            local _channel_macros = CHANNEL_MACROS[chan_idx_a1]
            for chan_macro_idx = 1, #_channel_macros do
                local chan_macro_name = _channel_macros[chan_macro_idx]
                local chan_macro_symbol = "wMacro@" .. channel_name .. "_" .. chan_macro_name
                local chan_macro_addr = g_symbols_ram[chan_macro_symbol]
                if chan_macro_addr ~= nil then -- paranoia
                    local noloop = chan_macro_name == "Vib"

                    -- Fixed macros are Arp macros at odd addresses
                    if chan_macro_name == "Arp" and (chan_macro_addr % 2 == 1) then
                        chan_macro_name = "Fixed"
                    end
                    print_fceux("   " .. chan_macro_name .. ": " .. macro_to_string_brief(chan_macro_addr, noloop), onscreen)
                    print_fceux("   " .. macro_tickertape(chan_macro_addr, 9, noloop), onscreen)
                end
            end

            -- display pattern
            if DISPLAY_PATTERN then
                local phrase_start = memory.readwordunsigned(phrase_macro_addr)
                local phrase_bank = 0x20
                local phrase_rom_start = phrase_start - 0x8000 + phrase_bank * 0x2000 + 0x10
                local phrase_offset = memory.readbyteunsigned(phrase_macro_addr + 2)
                local s = interpret_pattern(chan_idx_a1, phrase_rom_start, phrase_offset, track_number)
                print_fceux(s, false)
            end
        end
    end
end

-----------------------------------------------------------------------
-- main:

-- read stats from rom
read_nse_bank() -- (actually read from debug symbols)
read_tuning()

-- hook savestate button (to display info)
function on_save_state()
    emu.print("")
    emu.print("=========================================")
    emu.print("save state interrupt receieved. (frame " .. hex(emu.framecount()) .. ")")
    emu.print("")
    
    g_print_emu_only = true
    handle_input()
    display()
    g_print_emu_only = false
end
savestate.registersave(on_save_state)

-- code regions for interpreting channel idx
initialize_channel_idx_ranges()

-- mmc5 mapper watch
register_watchpoints()

-- assertions
register_asserts()

VerifyTick.register_watchpoints()

-- verify rom
verify_volume_table()

while (true) do
    if debuggee then
        debuggee.poll()
    end
    print_fceux_reset()
    handle_input()
    display()
    if not emu.paused() then
        emu.frameadvance();
    end
end


