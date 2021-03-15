chunkmap = {}

def chunk(label, data):
    if type(label) is not tuple:
        label = (label,)
    c = {
        "label": label,
        "data": data 
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

def write_chunk(chunk, buff, i, address=None):
    chunk["addr"] = address
    for d in chunk["data"]:
        if is_chunkptr(d):
            addr = deref_chunkptr(d)
            # little-endian
            buff[i] = addr & 0xff
            buff[i + 1] = (addr >> 8) & 0xff
            i += 2
        else:
            buff[i] = d
            i += 1
    return out

def chunkptr(label):
    return {
        "ptr": label
    }

def deref_chunkptr(ptr):
    label = ptr["ptr"]
    if label in chunkmap:
        chunk = chunkmap[label]
        if "addr" in chunk and chunk["addr"] is not None:
            return chunk["addr"]
        else:
            assert False, "chunk does not have an assigned address: " + label
    else:
        assert False, "no chunk with the following label exists: " + label

def is_chunkptr(v):
    return type(v) == dict and "ptr" in v