from utils import *
import string
import re

bnames = re.compile("B[0-9a-zA-Z]+_[0-9a-zA-Z]{0,4}")

outf = None
previdx = None

used = set()

def idx(bank, addr):
    if addr < 0x8000:
        return -1
    return bank // 2

def filename(bank, addr):
    base = "castlevania3build.nes."
    ext = ""
    if addr < 0x8000:
        ext = "ram"
    else:
        ext = hex(bank // 2)[2:]
    return base + ext + ".nl"

printable = set(string.printable)

with open('castlevania3.sym') as f:
    for line in f.readlines():
        line = line.strip()
        if line.startswith(";"):
            continue
        if len(line) < 9:
            continue
        if line[2] != ":" or line[7] != " ":
            continue
        bank = conv(line[0:2])
        addr = conv(line[3:7])
        name = line[8:]
        if bnames.match(name):
            # skip filler names
            continue
        
        if (idx(bank, addr), addr) in used and not name.startswith("wNSE_genVar"):
            continue
        else:
            used.add((idx(bank, addr), addr))
        
        if idx(bank, addr) != previdx:
            previdx = idx(bank, addr)
            if outf:
                outf.close()
            outf = open(filename(bank, addr), "w")
        hex4 = hex(addr)[2:].upper()
        while len(hex4) < 4:
            hex4 = "0" + hex4

        oline = "$" + hex4 + "#" + name.replace("#","_").replace(" ", "_") + "#\n"

        outf.write(''.join(filter(lambda x: x in printable, oline)))

if outf:
    outf.close()