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
        return
    end
    if onscreen or onscreen == nil then
        gui.text(4,12 + g_line * 8, s)
        g_line = g_line + 1
    end
end

--------------------------------------------------------------------------------
-- imports
-- (order is important.)

-- lua utilities (fceux-agnostic).
require("util")

-- global variable definitions
require("globals")

-- adjusts some globals
require("parse_clargs")

-- functions for reading/parsing domain-specific information from RAM.
require("ram_parser")

-- functions for parsing pharse patterns
require("nse_opcodes")

-- this is printed to the fceux lua script window (to verify the script works)
emu.print("starting...")

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

    -- current channel
    local channel_idx = ram_read_byte_by_name("wChannelIdx_a1")
    local channel_idx_str = "channel-idx: " .. tostring(channel_idx) .. "  "
    if channel_idx == 0 then
        channel_idx_str = channel_idx_str .. "z:" .. CHANNEL_NAMES[1]
    elseif channel_idx == #CHANNEL_NAMES then
        channel_idx_str = channel_idx_str .. "a1:" .. CHANNEL_NAMES[channel_idx]
    elseif channel_idx < #CHANNEL_NAMES then
        channel_idx_str = channel_idx_str .. "a1:" .. CHANNEL_NAMES[channel_idx] .. "/z:" .. CHANNEL_NAMES[channel_idx + 1]
    end
    print_fceux(channel_idx_str)

    local soundinfo = sound.get()
    
    -- each channel
    for chan_idx_a1 = 1, CHAN_COUNT do
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
            display_stat("rows-next-a1", "wMusChannel_RowsToNextCommand_a1", chan_idx_a1, onscreen)
            if channel_name ~= "DPCM" then
                display_stat("pitch", "wMusChannel_BasePitch", chan_idx_a1, onscreen)
                display_stat("volume", "wMusChannel_BaseVolume", chan_idx_a1, onscreen)
                display_stat("arpxy", "wMusChannel_ArpXY", chan_idx_a1, onscreen)
                display_stat("portrate", "wMusChannel_portrate", chan_idx_a1, onscreen)
                if channel_name ~= "Noise" then
                    display_stat("detune", "wMusChannel_BaseDetune", chan_idx_a1, onscreen)
                end
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
                    print_fceux("   " .. chan_macro_name .. ": " .. macro_to_string_brief(chan_macro_addr, noloop), onscreen)
                    print_fceux("   " ..macro_tickertape(chan_macro_addr, 9, noloop), onscreen)
                end
            end

            -- display pattern
            if DISPLAY_PATTERN then
                local phrase_start = memory.readwordunsigned(phrase_macro_addr)
                local phrase_bank = 0x20
                local phrase_rom_start = phrase_start - 0x8000 + phrase_bank * 0x2000 + 0x10
                local phrase_offset = memory.readbyteunsigned(phrase_macro_addr + 2)
                local s = interpret_pattern(chan_idx_a1, phrase_rom_start, phrase_offset)
                print_fceux(s, false)
            end
        end
    end
end

-----------------------------------------------------------------------
-- main:

-- read stats from rom
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

-- mmc5 mapper watch
register_mapper_watch()

while (true) do
    print_fceux_reset()
    handle_input()
    display()
    if not emu.paused() then
        emu.frameadvance();
    end
end




