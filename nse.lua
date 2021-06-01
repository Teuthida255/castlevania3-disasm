-- Displays debug info for sound engine
-- args: [--solo-<CHNAME>] [--mute-<CHNAME>] [--render]
-- set environment variable CV3_DEBUG_LUA_ARGS to pass args, or use fceux's script window.
-- press save-state button to get a snapshot of the sound engine state printed in fceux's script window.

package.path = "?.lua;lua/?.lua"

require("util")

-- merge 
g_symbols_ram = {}
for k,v in pairs((require "symbols_ram")["g_symbols_ram"])
    do g_symbols_ram[k] = v
end
for k,v in pairs((require "symbols_const")["g_symbols_const"])
    do g_symbols_ram[k] = v
end

CHANNEL_NAMES = {"Sq1", "Sq2", "Tri", "Noise", "DPCM", "Sq3", "Sq4"}
CHANNEL_MACROS = {
    {"Arp", "Detune", "Vol", "Duty", "Vib"},
    {"Arp", "Detune", "Vol", "Duty", "Vib"},
    {"Arp", "Detune", "Length", "Vib"},
    {"Arp", "Vol", "Vib"},
    {},
    {"Arp", "Detune", "Vol", "Duty", "Vib"},
    {"Arp", "Detune", "Vol", "Duty", "Vib"},
}

CHANNEL_REGISTERS = {
    {"SQ1_VOL", "SQ1_SWEEP", "SQ1_LO", "SQ1_HI"},
    {"SQ2_VOL", "SQ2_SWEEP", "SQ2_LO", "SQ2_HI"},
    {"TRI_LINEAR", "TRI_LO", "TRI_LO"},
    {"NOISE_VOL", "NOISE_LO", "NOISE_HI"},
    {"DMC_FREQ", "DMC_RAW", "DMC_START", "DMC_LEN"},
    {"MMC5_PULSE1_VOL", "MMC5_PULSE1_LO", "MMC5_PULSE1_HI"},
    {"MMC5_PULSE2_VOL", "MMC5_PULSE2_LO", "MMC5_PULSE2_HI"}
}

CHANNEL_CACHE_REGISTERS = {
    {"Vol", "Lo", "Hi"},
    {"Vol", "Lo", "Hi"},
    {"Vol", "Lo", "Hi"},
    {"Vol", "Lo"},
    {},
    {"Vol", "Lo", "Hi"},
    {"Vol", "Lo", "Hi"}
}

g_render = false
g_line = 0
g_channel = 0 -- zero-indexed
g_print_emu_only = false
CHAN_COUNT = 7
STR_START = 1 -- conceptually, this is 0 in C
g_select_high = false
g_frame_idx = 0

DISPLAY_CHANNELS = {true, true, true, true, true, true, true}

-- command line args
if arg == nil or arg == "" then
    local envargs = os.getenv("CV3_DEBUG_LUA_ARGS")
    if envargs ~= nil then
        arg = ". " .. envargs
    end
end
if arg ~= nil then
    if type(arg) == "string" then
        arg = split(arg)
    end
    if type(arg) == "table" then
        for i, a in ipairs(arg) do
            if i ~= 0 and a ~= nil and a ~= "" then
                if string.lower(a) == "--render" then
                    g_render = true
                end
                -- mute/solo channel data?
                for channel_idx, channel in ipairs(CHANNEL_NAMES) do
                    if string.lower("--mute-" .. channel) == string.lower(a) then
                        DISPLAY_CHANNELS[channel_idx] = false
                    end
                    if string.lower("--solo-" .. channel) == string.lower(a) then
                        g_channel = channel_idx - 1
                        for j = 1,#DISPLAY_CHANNELS do
                            DISPLAY_CHANNELS[j] = (j == channel_idx)
                        end
                    end
                end
            end
        end
    end
end

emu.print("starting...")

-- ternary if
function tern(c, t, f)
    if c then
        return t
    else
        return f
    end
end

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

function channel_is_square(ch_idx)
    return ch_idx < 2 or ch_idx >= 5
end

function macro_is_null(macroAddr)
    return memory.readwordunsigned(macroAddr) == 0
end

function ram_read_byte_by_name(name, offset)
    if offset == 0 or offset == nil then
        return memory.readbyteunsigned(g_symbols_ram[name])
    else
        memory.readbyteunsigned(g_symbols_ram[name] + offset)
    end
end

function ram_read_word_by_name(name)
    return memory.readwordunsigned(g_symbols_ram[name])
end

function macro_to_string_brief(macroAddr, noloop)
    local addr = memory.readwordunsigned(macroAddr)
    local offset = memory.readbyteunsigned(macroAddr + 2)
    local loop = memory.readbyteunsigned(addr)
    local loopstr = ""
    if noloop then
        -- indicate loop point is 0, and that's special
        loopstr = " (@0*)"
    else
        if loop == 0 then
            -- loop point of 0 is an error, since the first macro data byte should be at index 1
            loopstr = " (@!!)"
        elseif loop >= 2 then
            loopstr = string.format(" (@%02x)", loop)
        end
        if addr == 0 then
            loopstr = " (--)"
        end
    end
    if addr == 0 then
        return string.format("NULL+%02x%s", offset, loopstr)
    else
        return string.format("%04x+%02x%s", addr, offset, loopstr)
    end
end

function macro_tickertape(macroAddr, length, noloop)
    local addr = memory.readwordunsigned(macroAddr)
    if addr == 0 then
        return "--"
    end
    -- current offset of macro value
    local offset = memory.readbyteunsigned(macroAddr + 2)
    local loop_point = memory.readbyteunsigned(addr)
    local start_point = tern(noloop, 0, 1)
    local s = ""
    local lbound = math.max(math.floor(offset - length * 1 / 4), start_point)
    for i = lbound, lbound + length - 1, 1 do
        local val = memory.readbyteunsigned(addr + i)
        local k = "  "
        if i == loop_point and not noloop then
            if i == start_point then
                k = "@:"
            elseif i == offset then
                k = "@["
            elseif i == offset + 1 then
                k = "]@"
            end
        else
            if i == start_point then
                k = " :"
            elseif i == offset then
                k = " ["
            elseif i == offset + 1 then
                k = "] "
            end
        end

        if i == start_point then
            if i == offset then
                k = k .. "["
            else
                k = " " .. k
            end
        end

        s = s .. k .. string.format("%02x", val)
    end
    return s
end

function display_stat(title, varname, chan_idx_a1)
    print_fceux(title .. " " .. CHANNEL_NAMES[chan_idx_a1] .. ": " .. string.format("%02x", ram_read_byte_by_name(varname, chan_idx_a1 - 1)))
end

function handle_input()
    local input = joypad.readimmediate(1)
    if input["select"] then
        if not g_select_high then
            g_channel = (g_channel + 1) % CHAN_COUNT
        end
        g_select_high = true
    else
        g_select_high = false
    end
end

function display()
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
            display_stat("rows-next-a1", "wMusChannel_RowsToNextCommand_a1", chan_idx_a1)
            if channel_name ~= "DPCM" then
                display_stat("pitch", "wMusChannel_BasePitch", chan_idx_a1)
                display_stat("volume", "wMusChannel_BaseVolume", chan_idx_a1)
                display_stat("arpxy", "wMusChannel_ArpXY", chan_idx_a1)
                display_stat("portrate", "wMusChannel_portrate", chan_idx_a1)
                if channel_name ~= "Noise" then
                    display_stat("detune", "wMusChannel_BaseDetune", chan_idx_a1)
                end
            end

            -- display cached channel registers
            do
                local s = "CACHE. "
                for register_idx, register_name in ipairs(CHANNEL_CACHE_REGISTERS[chan_idx_a1]) do
                    local register_value = ram_read_byte_by_name("wMix_CacheReg_" .. channel_name .. "_" .. register_name)
                    s = s .. register_name:gsub(channel_name .. "_", "") .. ":" .. HX(register_value) .. " "
                end
                print_fceux(s, onscreen)
            end

            -- display channel registers
            do
                local s = "REG. "
                for register_idx, register_name in ipairs(CHANNEL_REGISTERS[chan_idx_a1]) do
                    local register_value = ram_read_byte_by_name(register_name)
                    s = s .. register_name:gsub(channel_name:upper() .. "_", ""):ulower() .. ":" .. HX(register_value) .. " "
                end
                print_fceux(s, onscreen)
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
        end
    end
end

-- main:

-- we use on_save_state to perform debugging tasks.
function on_save_state()
    emu.print("")
    emu.print("=========================================")
    emu.print("save state interrupt receieved.")
    emu.print("")
    g_print_emu_only = true
    handle_input()
    display()
    g_print_emu_only = false
end
savestate.registersave(on_save_state)

while (true) do
    print_fceux_reset()
    handle_input()
    display()
    if not emu.paused() then
        emu.frameadvance();
    end
end




