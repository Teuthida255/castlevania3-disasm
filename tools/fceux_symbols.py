from utils import *
import string
import re
import os
import symparser

outf = None
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

    oline = "$" + hex4 + "#" + name.replace("#","_").replace(" ", "_") + "#\n"

    outf.write(''.join(filter(lambda x: x in printable, oline)))

if outf:
    outf.close()