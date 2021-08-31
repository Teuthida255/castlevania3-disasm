import math

chunkmap = {}

def positive_modulo(a, b):
    return (a - math.floor(a / b) * b)

def chunk(label, data, maxlo=0xff, offset=0, **kwargs):
    if type(label) is not tuple:
        label = (label,)
    c = {
        "label": label,
        "data": data,
        "maxlo": maxlo,
        "offset": offset,
        "align": kwargs.get("align", 1),
        "alignoff": kwargs.get("alignoff", 0),
        # vbank: 'virtual bank'. May not map 1-1 to actual banks.
        "vbank": kwargs.get("vbank", 0),
        "minaddr": kwargs.get("minaddr", 0x8000)
    }
    for i, d in enumerate(c["data"]):
        if type(d) != dict:
            if d < 0 and d >= -128:
                d += 0x80
                c["data"][i] = d
            assert d >= 0 and d < 0x100
    chunkmap[label] = c
    return c

def nullchunk(label):
    if type(label) is not tuple:
        label = (label,)
    c = {
        "label": label,
        "data": None,
        "maxlo": 0xff,
        "offset": 0
    }
    chunkmap[label] = c
    return c

def chunk_len(chunk):
    c = 0
    for d in chunk["data"]:
        if is_chunkptr(d):
            c += 2
        else:
            c += 1
    return c

# sets chunk to be at another chunk
def associate_chunk(chunksrc, chunkdst):
    if is_chunkptr(chunksrc):
        chunksrc = chunkmap[chunksrc["ptr"]]
    if type(chunksrc) == str:
        chunksrc = (chunksrc,)
    if type(chunksrc) == tuple:
        chunksrc = chunksrc[chunk]
    assert(is_chunk(chunksrc))

    if is_chunkptr(chunkdst):
        chunkdst = chunkmap[chunkdst["ptr"]]
    if type(chunkdst) == str:
        chunkdst = (chunkdst,)
    if type(chunkdst) == tuple:
        chunkdst = chunkmap[chunkdst]
    assert(is_chunk(chunkdst))

    chunksrc["assoc"] = chunkdst["label"]

# sets chunk addr without writing it
def assign_chunk(chunk, address, bank):
    if is_chunkptr(chunk):
        chunk = chunkmap[chunk["ptr"]]
    if type(chunk) == str:
        chunk = (chunk,)
    if type(chunk) == tuple:
        chunk = chunkmap[chunk]
    assert(is_chunk(chunk))
    chunk["addr"] = address
    chunk["bank"] = bank

# returns number of bytes advanced
# (address may be modified)
def write_chunk(chunk, buff, i, address=None, bank=None, iend=None):
    steps = 0
    if address is None:
        address = i
    addrlo = address & 0xFF

    if is_chunkptr(chunk):
        chunk = chunkmap[chunk["ptr"]]
    if type(chunk) == str:
        chunk = (chunk,)
    if type(chunk) == tuple:
        chunk = chunkmap[chunk]
    assert(is_chunk(chunk))

    if chunk["data"] is None:
        chunk["addr"] = 0x0
        return 0
    
    if chunk.get('assoc', None) is not None:
        chunkassoc = chunkmap[chunk['assoc']]
        chunk["addr"] = chunkassoc["addr"]
        chunk["bank"] = chunkassoc["bank"]
        return 0

    if addrlo > chunk["maxlo"]:
        # skip some data and leave it unused
        steps = 0x100 - addrlo
        address += steps
        i += steps

    # ensure aligned
    if chunk["align"] > 1:
        steps = positive_modulo(chunk["align"] - address, chunk["align"]) + chunk["alignoff"]        
        address += steps
        i += steps

    # error if address not in valid range
    if chunk["minaddr"] is not None:
        assert address >= chunk["minaddr"], str(chunk["label"]) + ": address " + hex(address) + " less than minimum address " + hex(chunk["minaddr"])

    chunk["addr"] = address + chunk["offset"]
    chunk["bank"] = bank
    for d in chunk["data"]:
        if is_chunkptr(d):
            assert len(buff) - i >= 2
            addr = deref_chunkptr(d)
            # little-endian
            if "mapping" not in d:
                buff[i] = addr & 0xff
                buff[i + 1] = (addr >> 8) & 0xff
                i += 2
                steps += 2
            else:
                bytes = d["mapping"](addr)
                for j, b in enumerate(bytes):
                    buff[i + j] = b
                i += len(bytes)
                steps += len(bytes)
        else:
            assert len(buff) - i >= 1
            assert d >= 0 and d < 0x100
            buff[i] = d
            i += 1
            steps += 1
    if iend is not None and i > iend:
        raise Exception("bank end exceeded")
    return steps

def chunkptr(*args, **kwargs):
    if len(args) == 1 and type(args[0]) == tuple:
        label = args[0]
    elif len(args) > 1:
        label = tuple(args)
    else:
        label = None
    return {
        "ptr": label,
        **kwargs
    }

def chunkaddr(ptr):
    if is_chunkptr(ptr):
        ptr = ptr["ptr"]
    if is_chunk(ptr):
        ptr = ptr["label"]
    return chunkmap[ptr]["addr"]

def deref_chunkptr(ptr):
    label = ptr["ptr"]
    if label == None:
        return 0
    if label in chunkmap:
        chunk = chunkmap[label]
        if "addr" in chunk and chunk["addr"] is not None:
            return chunk["addr"]
        else:
            assert False, "chunk does not have an assigned address: " + str(label)
    else:
        assert False, "no chunk with the following label exists: " + str(label)

def get_chunk(label):
    if label == None:
        return 0
    if label in chunkmap:
        return chunkmap[label]
    return None

def chunk_is_null(label):
    return get_chunk(label)["data"] is None

def is_chunkptr(v):
    return type(v) == dict and "ptr" in v

def is_chunk(v):
    return type(v) == dict and "label" in v and "maxlo" in v and "data" in v