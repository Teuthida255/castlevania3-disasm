from utils import *
import string
import re
import os
import symparser

outf = None
outf_lua_ram = open("lua/symbols_ram.lua", "w")
outf_lua_ram.write("-- this file is generated automatically by fceux_symbols.py\n")
outf_lua_ram.write("g_symbols_ram = {}\n")
outf_lua_ram.write("g_symbols_ram_bank = {}\n")
previdx = None

started_files = set()

def idx(bank, addr):
    if addr < 0x8000:
        return -1
    return bank // 2

def filename(bank, addr):
    base = os.path.join("build", "castlevania3build.nes.")
    ext = ""
    if addr < 0x8000:
        ext = "ram"
    else:
        ext = hex(bank // 2)[2:]
    return base + ext + ".nl"

printable = set(string.printable)

symbols = symparser.symparse("castlevania3.sym", "list:(symbol,bank,addr)")

revmap = [
    (bank, addr, name) for name, bank, addr in symbols
]

# add in extra macro-defined symbols from wram_ext.s
definebasic = re.compile("^\\.define\\s+([a-zA-Z@_0-9]+)\\s+([a-zA-Z@_0-9]+)$")
defineplus = re.compile("^\\.define\\s+([a-zA-Z@_0-9]+)\\s+([a-zA-Z@_0-9]+)\\s*\\+\\s*([a-zA-Z@_0-9]+)$")
extra_macrodefs = {
    "": 0,
    "0": 0,
    "1": 1,
    "2": 2,
    "3": 3,
    "4": 4,
    "5": 5,
    "NSE_SQ1": 0,
    "NSE_SQ2": 1,
    "NSE_TRI": 2,
    "NSE_NOISE": 3,
    "NSE_DPCM": 4,
    "NSE_SQ3": 0,
    "NSE_SQ4": 0,
}
extras = {}
with open("include/wram_ext.s") as f:
    for line in f.readlines():
        for regex in [definebasic, defineplus]:
            m = regex.match(line)
            if m:
                name = m.group(1)
                addrname = m.group(2)
                offset = m.group(3) if regex == defineplus else ""
                assert offset in extra_macrodefs, "unknown offset: " + offset
                extras[addrname] = (name, extra_macrodefs[offset])
i = -1
for bank, addr, name in revmap + []:
    i = i + 1
    extra = extras[name] if name in extras else None
    if extra:
        revmap.insert(i, (bank, addr + extra[1], extra[0]))
        i = i + 1

# write symbols
used = set()
for bank, addr, name in revmap:
    was_used = (bank, addr) in used
    used.add((bank, addr))
    if idx(bank, addr) != previdx:
        previdx = idx(bank, addr)
        if outf:
            outf.close()
        fname = filename(bank, addr)
        outf = open(fname, "a" if fname in started_files else "w")
        started_files.add(fname)
    hex4 = hex(addr)[2:].upper()
    while len(hex4) < 4:
        hex4 = "0" + hex4

    sanname = name.replace("#","_").replace(" ", "_")
    oline = "$" + hex4 + "#" + sanname + "#\n"

    outf_lua_ram.write('g_symbols_ram["' + name.replace('"', '\\"') + '"] = 0x' + hex4 + "\n")
    if addr >= 0x8000:
        outf_lua_ram.write('g_symbols_ram_bank["' + name.replace('"', '\\"') + '"] = ' + hex(bank) + "\n")

    if not was_used:
        outf.write(''.join(filter(lambda x: x in printable, oline)))

outf_lua_ram.write("symbols = {g_symbols_ram=g_symbols_ram, g_symbols_ram_bank=g_symbols_ram_bank}\nreturn symbols")

if outf:
    outf.close()