from utils import *
import string
import re

bnames = re.compile("B[0-9a-zA-Z]+_[0-9a-zA-Z]{0,4}")

printable = set(string.printable)

def symparse(path, fmt="dict:symbol->(bank,addr)"):
    if fmt not in ["dict:symbol->(bank,addr)", "list:(symbol,bank,addr)"]:
        assert False
    symlist = []
    with open(path) as f:
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
            name = name.strip()
            if bnames.match(name):
                # skip filler names
                continue
            symlist.append((name, bank, addr))
    if fmt == "dict:symbol->(bank,addr)":
        return {
            s[0]: s[1:] for s in symlist
        }
    elif fmt == "list:(symbol,bank,addr)":
        return symlist
    else:
        assert False, "unsupported format: " + fmt

if __name__ == "__main__":
    symbols = symparse("castlevania3.sym")
    breakpoint()