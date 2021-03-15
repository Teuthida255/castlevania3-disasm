from utils import *
from ftTextParser import ftParseTxt
from chunks import *

# TODO: optimize phrase chunks

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
def get_rows_in_dpcm_phrase(pattern):
    for i, instrrows in enumerate(pattern):
        for row in instrrows:
            for effect in row["effects"]:
                if "D00" == effect:
                    return i+1
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
            *[chunkptr("song", song_idx, "channel", channel_idx, "instr", i) for i in range(NUM_INSTRS)],
            *[
                chunkptr("song", song_idx, "channel", channel_idx, "phrase", i) for i in rlen(
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
            *[chunkptr(("song", i, "channel", j)) for j in range(NUM_CHANS)]
            # phrase data
            *flatten([
                # rows in this frame's phrases
                [get_rows_in_dpcm_phrase(ft_track["patterns"][
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
    "A": 10,
    "A#": 11,
    "B": 12,
}

opcodes = {
    "A-0": None,
    "A#0": 1, #...
    "A-0-echo": 0x4F, #...
    "release": 0x4E,
    "tie": 0x9E,
    "continue-pitch": 0x9F,
    "volume": 0xB8,
    "channel-pitch": 0xA0
    "cut": 0xA1, #...
    "arpxy": 0xB1,
    "vibrato": 0xB2,
    "sweep": 0xB3,
    "sweep-cancel": 0xB4,
    "length-counter": 0xB5,
    "linear-counter": 0xB6,
    "portamento": 0xB7,
    "vibrato-cancel": 0xB8,
    "groove": 0xC0 #...
}

def note_opcode(note, echo=False):
    if echo:
        return opcodes["A-0-echo"] + note
    else:
        if note == 0:
            return opcodes["A-0"]
        else:
            return opcodes["A-#"] + note - 1

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
        note_value = note_value[note[:2]]
        return note_value + 12 * int(note[2]) - (1 if note_value < note_values["A-"] else 0)

    assert False, "unknown note value: " + note

def make_phrase_data(song_idx, chan_idx, pattern_idx):
    track = ft["tracks"][song_idx]
    pattern = track["patterns"][pattern_idx]
    phrase = pattern[chan_idx]
    data = []
    
    state_instr = None
    state_vol = None
    state_echovol = 0 # reasonable default
    state_note = None
    state_sweep = False

    wait_data = {
        "wait_idx": 0,
        "wait_byte_idx": 0
        "state_cut": False
    }

    echo_buffer = []

    def out_byte(v):
        assert v >= 0 and v < 0x100
        data += [v]
    
    def out_nibbles(hi, lo):
        assert hi >= 0 and hi < 0x10
        assert lo >= 0 and lo < 0x10
        out_byte(
            ((hi << 4) & 0xf0)
            | (lo & 0x0f)
        )

    def set_wait(row_idx):
        wait_amount = row_idx - wait_data["wait_idx"]
        assert wait_amount > 0, "cannot wait for 0 frames"
        if row_idx > 0:
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
            

    for row_idx, row in phrase:
        note = row["note"]
        instr = row["instr"]
        effects = row["effects"]
        ampersand = False
        if instr == "&&":
            instr = None
            ampersand = True

        vol = row["vol"]
        cut = note == "---"
        release = note == "==="
        note_change = False
        early_break = False
        state_cut = False

        # check if a new pitch (note) is set
        if note and not cut and not release:
            if note.startswith("^"):
                # echo buffer
                val = note[1:]
                if va[0] == "-":
                    val = note[2]
                val = int(val, 16)
                assert val < len(echo_buffer), "reaching into previous pattern not allowed for echo buffer"
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
            if op in ["P", "C", "D"]:
                early_break = True
            if op == "P":
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
                if nibx[0] == 0 or niby[0] == 0:
                    # cancel vibrato
                    out_byte(opcodes["vibrato-cancel"])
                else:
                    # vibrato
                    out_byte(opcodes["vibrato"])
                    data.append(
                        chunkptr("vibrato", nibx[0], nibx[1])
                    )
            elif op == "H" or op == "I":
                effect_applied = True
                negate_flag = 0 if op == "H" else 8
                if nibx[0] == 0 and nibx[1] == 0:
                    assert False, "phase reset feature not supported"
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
        if vol != state_vol:
            vol_change = vol != state_vol
            state_vol = vol

        # set instrument (state)
        if instr is not None:
            state_instr = instr
        
        wait_amount = row_idx - wait_idx

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
        elif note:
            # a note proper!
            echo = False # TODO: echo notes?
            
            # write volume change if necessary
            if vol_change:
                out_byte(opcodes["volume"])
                out_nibbles(echo_vol, state_vol)
            
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
            assert not state_sweep, "hardware sweep cannot be active at end of frame."
            break
    
    return data


            





# indexed as listed in 0cc's exported .txt
phrase_chunks = dict()

def make_phrase_chunks_for_song():
    for track_idx, track in enumerate(ft["tracks"]):
        phrase_chunks[track_idx] = [[] for i in range(NUM_CHANS)]
        for pattern_idx in enumerate(track["patterns"]):
            pattern = track["patterns"][pattern_idx]
            for chan_idx, chpattern in enumerate(pattern):
                data = make_phrase_data(song_idx, chan_idx, pattern_idx)
                phrase_chunks[song_idx][chan_idx].append(chunk(
                    ("song", track_idx, "channel", chan_idx, "phrase", pattern_idx),
                    data
                ))

def ft_to_data(path):
    global ft
    ft = ftParseTxt(path)

    make_phrase_chunks()

    data = [
        chunk("song_table", [
            chunkptr(("song", i))
            for i in range(len(ft["tracks"]))
        ]),
        *[song_chunk(i) for i in range(len(ft["tracks"]))],
        *[channel_chunk(i, j) for i in range(len(ft["tracks"])) for j in range(NUM_CHANS)],
        *flatten([phrase_chunk for phrase_chunk in channel for channel in phrase_chunks[song_idx] for song_idx in phrase_chunks])
    ]

    return data

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

