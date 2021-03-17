from utils import *
from ftTextParser import ftParseTxt
from chunks import *
import json
import os.path

dirname = os.path.dirname(os.path.realpath(__file__))

with open(os.path.join(dirname, "vibrato.json")) as f:
    vibrato_json = json.load(f)

ft = None

NUM_CHANS = 7
NUM_INSTRS = 0x10
NSE_DPCM = 4
NSE_CONDUCTOR = 6
MAX_WAIT_AMOUNT = 0x0F

def get_song_loop_point(i):
    ft_track = ft["tracks"][i]
    for frame in ft_track["frames"]:
        for phrase_idx in frame:
            phrase = ft_track["patterns"][phrase_idx]
            for instrrows in phrase:
                for row in instrrows:
                    for effect in row["effects"]:
                        if effect.startswith("B"):
                            return int(effect[1:], 16)
    return 0

# returns None if not found
def get_rows_in_phrase(pattern):
    for i, instrrows in enumerate(pattern):
        for row in instrrows:
            for effect in row["effects"]:
                if effect[0] == "D":
                    return i + 1
                if effect[0] == "B":
                    return i + 1
                if effect[0] == "C":
                    return i + 1
    return None

def channel_chunk(song_idx, channel_idx):
    ft_track = ft["tracks"][song_idx]
    return chunk(
        ("song", song_idx, "channel", channel_idx),
        [
            # instrument pointers
            #*[chunkptr("song", song_idx, "channel", channel_idx, "instr", i) for i in range(NUM_INSTRS)],
            *[0 for i in range(2*NUM_INSTRS)],
            #phrase pointers
            *[
                chunkptr("song", song_idx, "channel", channel_idx, "phrase", ft_track["frames"][i][channel_idx]) for i in rlen(
                    phrase_chunks[song_idx][channel_idx]
                )
            ]
        ]
    )

def song_chunk(i):
    ft_track = ft["tracks"][i]
    default_rows = ft_track["patternLength"]
    return chunk(
        ("song", i),
        [
            get_song_loop_point(i) + 2 * NUM_CHANS + 1,
            # instrument/channel tables
            *[chunkptr(("song", i, "channel", j)) for j in range(NUM_CHANS)],
            # phrase data
            *flatten([
                # rows in this frame's phrases
                [get_rows_in_phrase(ft_track["patterns"][
                        frame[NSE_DPCM]
                    ]) or default_rows
                ] + 
                # phrases in this frame (per channel)
                # TODO: assign phrase numbers per-song
                [phrase + NUM_INSTRS for phrase in frame]
                for frame_idx, frame in enumerate(ft_track["frames"])
            ]),
            0
        ]
    )

vibrato_used = set()

note_values = {
    "C-": 0,
    "C#": 1,
    "D-": 2,
    "D#": 3,
    "E-": 4,
    "E#": 5,
    "F-": 6,
    "F#": 7,
    "G-": 8,
    "G#": 9,
    "A-": 10,
    "A#": 11,
    "B-": 12,
}

opcodes = {
    # 0: "end of frame / loop frame"
    # 1 - 9A: notes (other than A-0)
    "tie": 0x9B,
    # 9C-9F: unused.
    "continue-pitch": 0xA0, # "slur"
    "cut": 0xA0, #A1-AF... lower nibble = wait
    "release": 0xB0,
    "groove": 0xB1,
    "volume": 0xB2,
    "channel-pitch": 0xB3,
    "arpxy": 0xB4,
    "vibrato": 0xB5,
    "vibrato-cancel": 0xB6,
    "sweep": 0xB7,
    "sweep-cancel": 0xB8,
    "length-counter": 0xB9,
    "linear-counter": 0xBA,
    "portamento": 0xBB,
    "A-0": 0xBC, # all other notes equal 2*semitones + echo
}

def note_opcode(note, echo=False):
    note_val = 2 * note + (1 if echo else 0)
    if note_val == 0:
        return opcodes["A-0"]
    else:
        return note_val

def get_note_value_from_str(note):
    assert len(note) == 3
    if note[2] == "#":
        val = int(note[0], 16)
        # weird optimization for special zero note
        if val == 0:
            return 0x10
        else:
            return val
    elif note[:2] in note_values:
        note_value = note_values[note[:2]]
        val = 12 * int(note[2]) + note_value - note_values["A-"]
        assert val >= 0 and val <= 0x4D
        return val

    assert False, "unknown note value: " + note

def make_phrase_data(song_idx, chan_idx, pattern_idx):
    track = ft["tracks"][song_idx]
    pattern = track["patterns"][pattern_idx]
    phrase = pattern[chan_idx]
    data = []

    if chan_idx == NSE_DPCM:
        return [1]
    
    state_instr = None
    state_vol = None
    state_echo_vol = None
    state_echo_vol_pending_addr = -1
    state_note = None
    state_sweep = False

    phrase_len = get_rows_in_phrase(pattern) or track["patternLength"]
    assert len(phrase) == track["patternLength"]

    wait_data = {
        "wait_idx": 0,
        "wait_byte_idx": 0,
        "state_cut": False
    }

    echo_buffer = []

    def out_byte(v):
        assert v >= 0 and v < 0x100
        data.append(v)
    
    def out_nibbles(hi, lo):
        assert hi >= 0 and hi < 0x10
        assert lo >= 0 and lo < 0x10
        out_byte(
            ((hi << 4) & 0xf0)
            | (lo & 0x0f)
        )

    def set_wait(row_idx):
        wait_amount = row_idx - wait_data["wait_idx"]
        if row_idx > 0:
            assert wait_amount > 0, "cannot wait for 0 frames"
            # set low nibble of previous wait
            data[wait_data["wait_byte_idx"]] |= wait_amount & 0xf

        wait_data["wait_idx"] = row_idx
        wait_data["wait_byte_idx"] = len(data) - 1
        pass
    
    def vol_nibble():
        if vol_change:
            assert state_vol != None, "need volume state, but it is not set."
            return state_vol
        if wait_data["state_cut"]:
            wait_data["state_cut"] = False
            assert state_vol != None, "need volume state, but it is not set."
            return state_vol
        return 0
            

    for row_idx, row in enumerate(phrase):
        note = row["note"]
        instr = row["instr"]
        effects = row["effects"]
        ampersand = False
        if instr == "&&":
            instr = None
            ampersand = True
        elif instr is not None:
            instr = int(instr, 16)

        vol = row["vol"]
        if vol is not None:
            vol = int(vol, 16)
        cut = note == "---"
        release = note == "==="
        note_change = False
        early_break = phrase_len - 1 == row_idx
        state_cut = False

        # check if a new pitch (note) is set
        if note and not cut and not release:
            if note.startswith("^"):
                # echo buffer
                val = note[1:]
                if val[0] == "-":
                    val = note[2]
                val = int(val, 16)
                assert val - 1 < len(echo_buffer), "reaching into previous pattern not allowed for echo buffer"
                note = echo_buffer[-val]
            else:
                # standard note
                note = get_note_value_from_str(note)

            # all notes get added to the echo buffer
            echo_buffer += [note]
            note_change = state_note != note
            state_note = note
        else:
            note = None

        # first write effects
        effect_applied = False
        sweep_applied = False
        for effect in effects:
            op = effect[0]
            args = effect[1:]
            argx = optional_hex(args)
            nibx = [optional_hex(args[0]), optional_hex(args[1])]
            if op == "O":
                # set groove
                out_byte(opcodes["groove"])
                data += [chunkptr(("song", song_idx, "groove", argx))]
            elif op == "P":
                # fine pitch
                # actually subtracts from pitch value, so the reciprocal value is applied
                out_byte(opcodes["channel-pitch"])
                out_byte(0x100 - argx)
                effect_applied = True
            elif op == "0":
                # arpxy
                effect_applied = True
                out_byte(opcodes["arpxy"])
                out_byte(argx)
            elif op == "3":
                # portamento
                out_byte(opcodes["portamento"])
                out_byte(argx)
                effect_applied = True
            elif op == "4":
                effect_applied = True
                if nibx[0] == 0 or nibx[1] == 0:
                    # cancel vibrato
                    out_byte(opcodes["vibrato-cancel"])
                else:
                    # vibrato
                    out_byte(opcodes["vibrato"])
                    vibrato_used.add(
                        (nibx[0], nibx[1])
                    )
                    data.append(
                        chunkptr(("vibrato", nibx[0], nibx[1]))
                    )
            elif op == "H" or op == "I":
                effect_applied = True
                negate_flag = 0 if op == "H" else 8
                if nibx[0] == 0 and nibx[1] == 0:
                    # ignore H00
                    pass
                else:
                    state_sweep = True
                    sweep_applied = True
                    out_byte(opcodes["sweep"])
                    out_nibbles(nibx[0] | 8, nibx[1] | negate_flag)
            elif effect[0:2] == "EE":
                # disable length/linear counter
                # TODO
                effect_applied = True
                pass
            elif op == "E":
                # alternative volume-set command
                if vol == None:
                    vol = argx
            elif op == "S":
                # length/linear counter
                # TODO
                effect_applied = True
                pass
            elif op in ["W", "X", "Y", "Z"]:
                # DPCM stuff
                pass
        
        # write volume if it has changed
        vol_change = False
        prev_vol = state_vol
        if vol is not None and vol != state_vol:
            vol_change = vol != state_vol
            state_vol = vol

        # set instrument (state)
        if instr is not None:
            state_instr = instr
        
        wait_amount = row_idx - wait_data["wait_idx"]

        # note (or cut or release or continue)
        if cut:
            # (low nibble of this is the 'wait' time)
            out_byte(opcodes["cut"])
            set_wait(row_idx)

            # need to remember that we've cut because
            # this sets the channel volume to zero.
            wait_data["state_cut"] = True

        elif release:
            if note_change:
                assert False, "change of pitch and release not allowed simultaneously"
            
            out_byte(opcodes["release"])
            out_nibbles(vol_nibble(), 0)
            set_wait(row_idx)
        elif ampersand:
            # continue

            if note_change:

                # end any hardware sweep (if necessary)
                if sweep_applied:
                    state_sweep = False
                    out_byte(opcodes["sweep-cancel"])

                # continue with new pitch
                out_byte(opcodes["continue-pitch"])

                # continue-pitch has two parameter bytes:

                #  (1) the new pitch (i.e. note in semitones)
                out_byte(note)

                #  (2) the volume to use | wait
                out_nibbles(vol_nibble(), 0)
                set_wait(row_idx)
            else:
                out_byte(opcodes["tie"])
                out_nibbles(vol_nibble(), 0)
                set_wait(row_idx)
        elif note is not None:
            # a note proper!
            echo = False # TODO: echo notes?
            
            # write volume change if necessary
            if vol_change:
                if state_echo_vol == state_vol or state_echo_vol_pending_addr >= 0:
                    # swap in echo volume
                    echo = True

                    if state_echo_vol_pending_addr >= 0:
                        state_echo_vol_pending_addr = -1
                        state_echo_vol = state_vol

                        # write echo vol at previous location
                        data[state_echo_vol_pending_addr] |= (state_echo_vol << 4)

                    # swap states
                    state_vol = state_echo_vol
                    state_echo_vol = prev_vol
                else:
                    # set volume
                    out_byte(opcodes["volume"])
                    state_echo_vol_pending_addr = len(data)
                    state_echo_vol = None
                    # write echo volume later if we figure out what we want it to be.
                    out_nibbles(0, state_vol)
            
            # end any hardware sweep (if necessary)
            if sweep_applied:
                state_sweep = False
                out_byte(opcodes["sweep-cancel"])
            
            # write note bytecode proper.
            out_byte(note_opcode(note, echo))

            # instrument and wait
            assert state_instr != None, "cannot play note without setting instrument."
            out_nibbles(state_instr, 0)
            set_wait(row_idx)
        elif vol_change:
            # change volume without any other effect.
            out_byte(opcodes["tie"])
            out_nibbles(state_vol, 0)
            set_wait(row_idx)
        elif wait_amount >= MAX_WAIT_AMOUNT or row_idx == 0 or effect_applied:
            # just need to tie; no other changes.
            out_byte(opcodes["tie"])
            out_nibbles(0, 0)
            set_wait(row_idx)
        
        if early_break or row_idx == len(phrase) - 1:
            # end of phrase
            set_wait(row_idx + 1)
            if state_sweep:
                print("Warning: hardware sweep active at end of frame; cropping it.")
                out_byte(opcodes["sweep-cancel"])
            
            break
    
    return data

def make_vibrato_chunks():
    chunks = []
    for vibrato in vibrato_used:
        vibratostr = "4" + HX(vibrato[0]) + HX(vibrato[1])
        chunks.append(chunk(
            ("vibrato", vibrato[0], vibrato[1]),
            vibrato_json[vibratostr]
        ))
    return chunks

def make_groove_chunks(track_idx):
    track = ft["tracks"][track_idx]
    grooves = ft["groove"]
    chunks = []
    for groove in grooves:
        assert 0 not in groove["data"]
        chunks.append(chunk(
            ("song", track_idx, "groove", groove["index"]),
            groove["data"] + [0] # add end marker
        ))
    return chunks


# indexed as listed in 0cc's exported .txt
phrase_chunks = dict()

def make_phrase_chunks():
    chunks =  []
    for track_idx, track in enumerate(ft["tracks"]):
        chunks += make_groove_chunks(track_idx)
        phrase_chunks[track_idx] = [[] for i in range(NUM_CHANS)]
        for pattern_idx in track["patterns"]:
            pattern = track["patterns"][pattern_idx]
            for chan_idx, chpattern in enumerate(pattern):
                data = make_phrase_data(track_idx, chan_idx, pattern_idx)
                phrase_chunks[track_idx][chan_idx].append(chunk(
                    ("song", track_idx, "channel", chan_idx, "phrase", pattern_idx),
                    data
                ))
                assert(is_chunk(phrase_chunks[track_idx][chan_idx][-1]))
        
        # only add the phrase chunks for the phrases which actually appear in the song
        used_chunks = set()
        for frame in track["frames"]:
            for chan_idx, phrase_idx in enumerate(frame):
                used_chunks.add((chan_idx, phrase_idx))
        for used_chunk in used_chunks:
            chan_idx = used_chunk[0]
            phrase_idx = used_chunk[1]
            ch = phrase_chunks[track_idx][chan_idx][phrase_idx]
            assert is_chunk(ch)
            chunks.append(ch)
    return chunks

def ft_to_data(path):
    global ft
    ft = ftParseTxt(path)

    chunks = make_phrase_chunks()

    chunks = make_vibrato_chunks() + chunks

    chunks += [
        *[channel_chunk(i, j) for i in range(len(ft["tracks"])) for j in range(NUM_CHANS)],
        *[song_chunk(i) for i in range(len(ft["tracks"]))],
        chunk("song_table", [
            chunkptr(("song", i))
            for i in range(len(ft["tracks"]))
        ])
    ]

    return chunks

# run this as a shell script
if __name__ == "__main__":
    import json
    import sys
    if len(sys.argv) != 2:
        print("usage: " + sys.argv[0] + " /path/to/ftexport.0cc")
        exit(1)
    j = json.dumps(ft_to_data(sys.argv[1]))
    if j == None:
        print("An error has occurred.")
        exit(2)
    print(j)
    exit(0)

