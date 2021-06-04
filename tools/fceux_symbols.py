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

revmap = {
    (bank, addr): name for name, bank, addr in symbols
}

for bank, addr in revmap:
    name = revmap[(bank, addr)]
    
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

    outf.write(''.join(filter(lambda x: x in printable, oline)))

outf_lua_ram.write("symbols = {g_symbols_ram=g_symbols_ram, g_symbols_ram_bank=g_symbols_ram_bank}\nreturn symbols")

if outf:
    outf.close()