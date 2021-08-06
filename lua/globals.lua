-- merge symbols
g_symbols_ram = {}
g_symbols_ram_bank = {}
assert(isModuleAvailable("symbols_ram"), "Please run fceux_symbols.py before using this lua script!")
for k,v in pairs((require "symbols_ram")["g_symbols_ram"])
    do g_symbols_ram[k] = v
end
for k,v in pairs((require "symbols_ram")["g_symbols_ram_bank"])
    do g_symbols_ram_bank[k] = v
end
for k,v in pairs((require "symbols_const")["g_symbols_const"])
    do g_symbols_ram[k] = v
end

require("symbols_data")

-- for debugging convenience mostly
CHAN_SQ1 = 0
CHAN_SQ2 = 1
CHAN_TRI = 2
CHAN_NOISE = 3
CHAN_DPCM = 4
CHAN_SQ3 = 5
CHAN_SQ4 = 6

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
    {chip = "rp2a03", chipinstr = "square1"},
    {chip = "rp2a03", chipinstr = "square1"},
    {},
    {},
    {},
    {},
    {}
}

CHANNEL_COUNT = 7

CHANNEL_CACHE_REGISTERS = {
    {"Vol", "Lo", "Hi"},
    {"Vol", "Lo", "Hi"},
    {"Vol", "Lo", "Hi"},
    {"Vol", "Lo"},
    {},
    {"Vol", "Lo", "Hi"},
    {"Vol", "Lo", "Hi"}
}

DISPLAY_CACHED_REGISTERS = false
TRACK_CHANNEL_INSTRUMENT = true
DISPLAY_CHANNEL_INSTRUMENT = true
DISPLAY_CHANNEL_VARS = true
DISPLAY_INTERPRETED_CACHED_REGISTERS = true
DISPLAY_REGISTERS = true
DISPLAY_PATTERN = true

g_render = false
g_line = 0
g_channel = 0 -- zero-indexed
g_print_emu_only = false
CHAN_COUNT = 7
STR_START = 1 -- conceptually, this is 0 in C
g_select_high = false
g_frame_idx = 0

DISPLAY_CHANNELS = {true, true, true, true, true, true, true}

CPU_HZ = 1789773
TUNING_A4_HZ = 440 -- replaced in ram_parser
NSE_BANK = 0x20 -- replaced in ram_parser