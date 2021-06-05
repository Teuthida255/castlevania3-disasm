from utils import groupBytes
from utils import *

def lineComps(line):
    return [c for c in splitq(line, " ") if c]

def join(_bytes):
    return " ".join(f'${b:02x}' for b in _bytes)

token_macros = [
    "MACRO",
	"MACROVRC6",
	"MACRON163",
	"MACROS5B",
]

token_insts = [
    "INST2A03",
    "INSTVRC6",
    "INSTS5B"
]

macro_names = ["volume", "arpeggio", "pitch", "hi-pitch", "duty"]

# returns dict containing ft data, representable in json.
def ftParseTxt(path):
    lines = []
    with open(path) as f:
        lines = f.read().splitlines()

    macros = {}
    dpcms = []
    grooves = []
    usegroove = []
    comps = []
    phrases = []
    instruments = []
    tracks = []

    currPattern = 0
    currRow = 0
    # keyed by pattern idx, lists keyed by row, lists keyed by instr idx

    data = {
        "title": "",
        "author": "",
        "copyright": "",
        "comment": "",
        "machine": 0,
        "framerate": 0,
        "expansion": 0,
        "vibrato": 0,
        "split": 0,
        "macros": macros,
        "tuning": [],
        "dpcm": dpcms,
        "groove": grooves,
        "tracks": tracks,
        "instruments": instruments
    }

    for line in lines:
        lc = lineComps(line)
        if len(lc) == 0:
            continue

        op = lc[0]

        if op == "#":
            continue

        args = lc[1:]
        z = [optional_dec(arg) for arg in args]
        x = [optional_hex(arg) for arg in args]

        if op == "TITLE":
            data["title"] = args[0]
        elif op == "AUTHOR":
            data["author"] = args[0]
        elif op == "COPYRIGHT":
            data["copyright"] = args[0]
        elif op == "COMMENT":
            data["comment"] += args[0].replace('""', '&quotə;').replace('"', '').replace("&quotə;", '"') + "\n"
        elif op == "MACHINE":
            data["machine"] = z[0]
        elif op == "FRAMERATE":
            data["framerate"] = z[0]
        elif op == "EXPANSION":
            data["expansion"] = z[0]
        elif op == "VIBRATO":
            data["vibrato"] = z[0]
        elif op == "SPLIT":
            data["split"] = z[0]
        elif op == "TUNING":
            data["tuning"] = z

        elif op == "DPCMDEF":
            dpcms.append({
                "index": z[0],
                "length": z[1],
                "name": z[2],
                "data": []
            })
            assert dpcms[-1]["index"] == len(dpcms) - 1

        elif op == "DPCM":
            dpcmBytes = args[1:]
            dpcms[-1]["data"].extend(map(lambda b: int(b, 16), dpcmBytes))
        
        elif op in token_macros:
            macros[(z[0], z[1])] = {
                "chipname": op,
                "chip": token_macros.index(op),
                "type": macro_names[z[0]],
                "typeidx": z[0],
                "index": z[1],
                "loop": z[2],
                "release": z[3],
                "setting": z[4],
                "data": z[6:]
            }
        
        elif op == 'GROOVE':
            assert len(z) - 3 == z[1], "groove length and data do not match"
            grooves.append({
                "index": z[0],
                "length": z[1],
                "data": z[3:]
            })
        
        elif op == "USEGROOVE":
            usegroove = z[1:]

        elif op in token_insts:
            instruments.append({
                "type": op,
                "index": z[0],
                "macros": z[1:6],
                "name": args[6].replace('"', ""),
                "dpcmkeys": {}
            })

        elif op == "KEYDPCM":
            o = z[1]
            n = z[2]
            note = o * 12 + n
            instruments[z[0]]["dpcmkeys"][note] = {
                "index": z[3],
                "pitch": z[4],
                "loop": z[5] == 1,
                "loopOffset": z[6],
                "delta": z[7]
            }

        elif op == "TRACK":
            tracks.append({
                "patternLength": z[0],
                "useGroove": len(tracks) in usegroove,
                "speed": z[1],
                "tempo": z[2],
                "title": args[3].replace('"', ""),
                "columns": [],
                "frames": [],
                "patterns": {}
            })

        elif op == ('COLUMNS'):
            tracks[-1]["columns"] = z[1:]

        elif op == ('ORDER'):
            tracks[-1]["frames"].append(list(map(lambda b: int(b, 16), args[2:])))

        elif op == ('PATTERN'):
            currPattern = x[0]
            patternData = tracks[-1]["patterns"]
            patternData[currPattern] = [[] for i in tracks[-1]["columns"]]

        elif op == ('ROW'):
            currRow = x[0]
            assert currRow == len(patternData[currPattern][0])
            instrIdx = 0
            currLCIdx = 3
            for numEffects in tracks[-1]["columns"]:
                instrData = lc[currLCIdx:currLCIdx+numEffects+3]
                instrData = [data if not ".....".startswith(data) else None for data in instrData]
                currLCIdx += numEffects + 3 + 1 # skip : as well

                patternData[currPattern][instrIdx].append({
                    "note": instrData[0],
                    "instr": instrData[1],
                    "vol": instrData[2],
                    "effects": [effect for effect in instrData[3:] if effect],
                })
                instrIdx += 1
        else:
            assert False, "unknown token: \"" + op + "\""
    return data

# run this as a shell script
if __name__ == "__main__":
    import json
    import sys
    if len(sys.argv) != 2:
        print("usage: " + sys.argv[0] + " /path/to/ftexport.0cc")
        exit(1)
    j = ftParseTxt(sys.argv[1])
    if j == None:
        print("An error has occurred.")
        exit(2)
    print(json.dumps(j))
    exit(0)

