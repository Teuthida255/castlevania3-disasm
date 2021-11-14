import symparser
import ftToData
from chunks import *
from utils import *

# base addresses for each bank
# (assumes bank is only ever loaded into one spot in RAM)
bankorg = {
    0x07: 0xC000,
    0x1e: 0xC000,
    0x20: 0x8000
}

banksize = 0x2000

def get_prg_addr(bank, addr):
    return bank * banksize + addr - bankorg[bank]

# gets address within bank
def get_bank_addr(bank, addr):
    return get_prg_addr(bank, addr) - banksize * bank

def get_bank_start_addr(bank):
    return bank * banksize

def get_bank_end_addr(bank):
    return (bank + 1) * banksize

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
        chunks = ftToData.ft_to_data("resources/AoC_Tests_Arp.txt")
        chunklabels = [chunk["label"] for chunk in chunks]

        # "null32" is defined in ftToData.py as 32 zeroes.
        # This already exists in the code at the 'nullTable' label.
        assign_chunk("null32", *symbols["nullTable"])
        
        # write chunks
        writecount = 0

        # physical banks and start addresses of vbanks
        outaddrs = {0: symbols["nse_soundData"], 1: ("dpcm-common", 0xC000)}

        # write each chunk
        for chunk in chunklabels:
            ch = get_chunk(chunk)
            vbank = ch["vbank"] if "vbank" in ch else 0
            assert vbank in outaddrs.keys(), "unknown virtual bank " + hex(vbank)
            outaddr = outaddrs[vbank]
            bank = outaddr[0]
            addr = outaddr[1]

            # common dpcm data is duplicated to two banks, 7 and 1e, so we must respect that.
            for bank in [bank] if bank != "dpcm-common" else [0x7, 0x1e]:
                # special handling --
                # let's not write the song table, because we are not using that yet.
                if chunk[0] == "song_table":
                    continue
                if chunk == ("song", 0):
                    # update song table pointer to point here.
                    write_bytes_at(prg, addr_soundtable_lo[0], addr_soundtable_lo[1] + 0x66, [addr & 0xff])
                    write_bytes_at(prg, addr_soundtable_hi[0], addr_soundtable_hi[1] + 0x66, [(addr >> 8) & 0xff])

                # write chunk
                #print("writing chunk", chunk, "to bank", "$" + HX(bank), "at", "$" + HX(addr))
                # TODO: pass max addr as well
                count = write_chunk(chunk, prg, get_prg_addr(bank, addr), addr, bank, get_bank_end_addr(bank))
                addrpost = addr + count
                writecount += count
                outaddrs[vbank] = (bank, addrpost)

                # append symbol
                ch = get_chunk(chunk)
                if ch is not None:
                    if "offset" in ch and ch["offset"] > 0:
                        symfile.write(HX(bank, 2) + ":" + HX(addr - ch["offset"], 4) + " PRE_" + fceux_symbol_from_label(chunk) + "\n")
                    symfile.write(HX(bank, 2) + ":" + HX(addr, 4) + " " + fceux_symbol_from_label(chunk) + "\n")
        print("bytes written:", hex(writecount))

        lua = ftToData.get_lua_symbols()
        with open("lua/symbols_data.lua", "w") as f:
            f.write(lua)