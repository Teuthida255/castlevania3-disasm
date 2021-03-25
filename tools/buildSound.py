import symparser
import ftToData
from chunks import *
from utils import *

# base addresses for each bank
# (assumes bank is only ever loaded into one spot in RAM)
bankorg = {
    32: 0x8000
}

banksize = 0x2000

def get_prg_addr(bank, addr):
    return bank * banksize + addr - bankorg[bank]

def get_bank_addr(bank, addr):
    return get_prg_addr(bank, addr) - banksize * bank

# returns (bank, addr) at end of chunk written
def write_bytes_at(prg, bank, addr, bytes):
    for i, byte in enumerate(bytes):
        byte = int(byte)
        assert byte >= 0 and byte < 0x100
        prg[get_prg_addr(bank, addr + i)] = byte
    return (bank, addr + len(bytes))
        
def write_word_at(prg, bank, addr, word):
    return write_bytes_at(prg, bank, addr, [word & 0xff, (word >> 8) & 0xff])

def add_addr(bank, addr, offset):
    return (bank, addr + offset)

def fceux_symbol_from_label(label):
    s = ""
    first = True
    for l in label:
        if not first:
            s += "_"
        first = False
        if type(l) is type(1):
            s += HX(l)
        else:
            s += str(l)
    return s

def build(prg):
    symbols = symparser.symparse("castlevania3.sym")
    with open("castlevania3.sym", "a") as symfile:
        symfile.write("\n")
        addr_soundtable_lo = symbols["nse_soundTable_lo"]
        addr_soundtable_hi = symbols["nse_soundTable_hi"]
        chunks = ftToData.ft_to_data("resources/AoC_Demo.txt")
        chunklabels = [chunk["label"] for chunk in chunks]

        assign_chunk("null32", *symbols["nullTable"])
        
        # write chunks
        outaddr = symbols["nse_soundData"]
        pre_addr = outaddr[1]
        for chunk in chunklabels:
            bank = outaddr[0]
            addr = outaddr[1]

            # let's not write the song table, because we are not using that yet.
            if chunk[0] == "song_table":
                continue
            
            if chunk == ("song", 0):
                write_bytes_at(prg, addr_soundtable_lo[0], addr_soundtable_lo[1] + 0x66, [addr & 0xff])
                write_bytes_at(prg, addr_soundtable_hi[0], addr_soundtable_hi[1] + 0x66, [(addr >> 8) & 0xff])

            # write chunk
            #print("writing chunk", chunk, "to bank", "$" + HX(bank), "at", "$" + HX(addr))
            # TODO: pass max addr as well
            addrpost = addr + write_chunk(chunk, prg, get_prg_addr(bank, addr), addr, bank)
            outaddr = (bank, addrpost)

            # append symbol
            ch = get_chunk(chunk)
            if ch is not None:
                if "offset" in ch and ch["offset"] > 0:
                    symfile.write(HX(bank, 2) + ":" + HX(addr - ch["offset"], 4) + " PRE_" + fceux_symbol_from_label(chunk) + "\n")
                symfile.write(HX(bank, 2) + ":" + HX(addr, 4) + " " + fceux_symbol_from_label(chunk) + "\n")
        print("bytes written:", hex(outaddr[1] - pre_addr))
        pre_addr = outaddr[1]