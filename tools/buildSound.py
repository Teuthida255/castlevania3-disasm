import symparser
import ftToData
from chunks import *
from utils import *

sound_replacements = {
    # replace song 66 with track 0
    0x66: 0
}

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

def get_bank(prg, bank):
    bankbase = banksize * bank
    return prg[bankbase:bankbase + banksize]

# returns (bank, addr) at end of chunk written
def write_bytes_at(prg, bank, addr, bytes):
    for i, byte in enumerate(bytes):
        byte = int(byte)
        assert byte >= 0 and byte < 0x100
        prg[get_prg_addr(bank, addr + i)] = byte
    return (bank, addr + len(bytes))
        
def write_word_at(prg, bank, addr, word):
    return write_bytes_at(prg, bank, addr, [word & 0xff, (word >> 8) & 0xff])

def build(prg):
    symbols = symparser.symparse("castlevania3.sym")
    print(symbols["nse_soundTable_lo"])
    print(symbols["nse_soundTable_hi"])
    print(symbols["nse_soundData"])
    chunks = ftToData.ft_to_data("resources/AoC_Demo.txt")
    chunklabels = [chunk["label"] for chunk in chunks]
    
    # write grooves
    outaddr = symbols["nse_soundData"]
    pre_addr = outaddr[1]
    for chunk in chunklabels:
        # let's not write the song table, because we are not using that yet.
        if chunk[0] == "song_table":
            continue

        # write chunk
        bank = outaddr[0]
        addr = outaddr[1]
        print("writing chunk", chunk, "to bank", "$" + HX(bank), "at", "$" + HX(addr))
        addrpost = addr + write_chunk(chunk, get_bank(prg, bank), get_bank_addr(bank, addr), addr)
        outaddr = (bank, addrpost)
    print("bytes written:", hex(outaddr[1] - pre_addr))
    pre_addr = outaddr[1]