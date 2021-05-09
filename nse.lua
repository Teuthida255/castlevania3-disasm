package.path = "?.lua;lua/?.lua"
symbols = require "symbols_ram"
g_symbols_ram = symbols["g_symbols_ram"]

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

g_line = 0
g_channel = 0
CHAN_COUNT = 7
STR_START = 1 -- conceptually, this is 0 in C
g_select_high = false
g_frame_idx = 0

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
        print("---------------------------------")
    end
end

function print_fceux(s, onscreen)
    if onscreen or onscreen == nil then
        gui.text(4,12 + g_line * 8, s)
        g_line = g_line + 1
    end
    if g_frame_idx == 1 then
        print(s)
    end
end

function channel_is_square(ch_idx)
    return ch_idx < 2 or ch_idx >= 5
end

function macro_is_null(macroAddr)
    return memory.readwordunsigned(macroAddr) == 0
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
    local offset = memory.readbyteunsigned(macroAddr + 2)
    local loop_point = memory.readbyteunsigned(addr)
    local s = ""
    local lbound = math.max(offset - length, tern(noloop, 0, 1))
    for i = lbound, lbound + length - 1, 1 do
        local val = memory.readbyteunsigned(addr + i)
        local k = "  "
        if i == 1 then
            k = " :"
        elseif i == offset then
            k = " ["
        elseif i == offset + 1 then
            k = "] "
        end

        if i == loop_point and not noloop then
            -- replace last space with @
            local index = string.find(k, " [^ ]*$")
            if index then
                k = string.sub(k, 1, index - 1) .. "@" .. string.sub(k, index + 1)
            end
        end

        if i == 1 then
            if i == offset then
                k = k .. "["
            else
                k = k .. " "
            end
        end

        s = s .. k .. string.format("%02x", val)
    end
    return s
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
    song_macro = g_symbols_ram["wMacro@Song"]
    print_fceux("song-macro: " .. macro_to_string_brief(song_macro));

    -- each channel
    for chan_idx_a1 = 1, CHAN_COUNT do
        local channel_name = CHANNEL_NAMES[chan_idx_a1]
        local phrase_macro_addr = g_symbols_ram["wMacro@" .. channel_name .. "_Phrase"]
        local onscreen = chan_idx_a1 == g_channel + 1
        print_fceux("---", false)
        print_fceux("channel " .. tostring(channel_name) .. " phrase " .. macro_to_string_brief(phrase_macro_addr), onscreen)
        print_fceux(macro_tickertape(phrase_macro_addr, 10), onscreen)
        local _channel_macros = CHANNEL_MACROS[chan_idx_a1]
        for chan_macro_idx = 1, #_channel_macros do
            local chan_macro_name = _channel_macros[chan_macro_idx]
            local chan_macro_symbol = "wMacro@" .. channel_name .. "_" .. chan_macro_name
            local chan_macro_addr = g_symbols_ram[chan_macro_symbol]
            if chan_macro_addr ~= nil then -- paranoia
                if macro_is_null(chan_macro_addr) then -- don't render if macro is set to null (to save space).
                    local noloop = chan_macro_name == "Vib"
                    print_fceux("   " .. chan_macro_name .. ": " .. macro_to_string_brief(chan_macro_addr, noloop), onscreen)
                    print_fceux("   " ..macro_tickertape(chan_macro_addr, 9, noloop), onscreen)
                end
            end
        end
    end
end

while (true) do
    print_fceux_reset()
    handle_input()
    display()
    if not emu.paused() then
        emu.frameadvance();
    end
end




