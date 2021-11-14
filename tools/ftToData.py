from utils import *
from ftTextParser import ftParseTxt, macro_names
from chunks import *
import json
import os.path

dirname = os.path.dirname(os.path.realpath(__file__))

with open(os.path.join(dirname, "vibrato.json")) as f:
    vibrato_json = json.load(f)

ft = None

NUM_CHANS = 7
NUM_INSTRS = 0x10
NSE_SQ = [0, 1, 5, 6]
NSE_TRI = 2
NSE_NOISE = 3
NSE_DPCM = 4
MAX_WAIT_AMOUNT = 0x0F
CHANNEL_NAMES = ["Sq1", "Sq2", "Tri", "Noise", "DPCM", "Sq3", "Sq4"]

# add/remove these for debugging
enabled_macros = ["vol", "duty", "arp"]

# debug symbol code to help lua debugging

channel_macros = [
    ["arp", "detune", "vol", "duty"], # sq1
    ["arp", "detune", "vol", "duty"], # sq2
    ["arp", "detune", "length"], # tri
    ["arpmode", "vol"], # noise
    [], # dpcm (does not have macros)
    ["arp", "detune", "vol", "duty"], # sq3
    ["arp", "detune", "vol", "duty"]  # sq4
]

ft_macro_type_idx = {
    "vol": 0,
    "length": 0,
    "arp": 1,
    "arpmode": 1, # also 4
    "detune": 2,
    "hi-detune": 3,
    "duty": 4,
}

def error_context(**kwargs):
    s = " ["
    first = True
    for kwarg in kwargs:
        if not first:
            s += ", "
        first = False
        s += kwarg + ": " + str(kwargs[kwarg])
    return s + "]"

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

def get_rows_in_frame(song_idx, frame_idx):
    ft_track = ft["tracks"][song_idx]
    default_rows = ft_track["patternLength"]
    frame = ft_track["frames"][frame_idx]
    pattern_lengths = list(filter(lambda x: x is not None, [
            get_rows_in_phrase(song_idx, pattern_idx, instr_idx) for instr_idx, pattern_idx in enumerate(frame)]
        ))
    return min(
        [default_rows] + pattern_lengths
    )

# returns None if not found
def get_rows_in_phrase(song_idx, pattern_idx, chan_idx):
    for i, row in enumerate(ft["tracks"][song_idx]["patterns"][pattern_idx][chan_idx]):
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
            *[chunkptr("song", song_idx, "channel", channel_idx, "instr", i) for i in range(NUM_INSTRS)],
            #phrase pointers
            *[
                chunkptr("song", song_idx, "channel", channel_idx, "phrase", ft_track["frames"][i][channel_idx]) for i in rlen(
                    ft_track["frames"]
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
            get_song_loop_point(i) * (NUM_CHANS + 1) + 2 * NUM_CHANS + 1,
            # instrument/channel tables
            *[chunkptr(("song", i, "channel", j)) for j in range(NUM_CHANS)],
            # phrase data
            *flatten([
                # rows in this frame's phrases
                [get_rows_in_frame(i, frame_idx) or default_rows
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
    "F-": 5,
    "F#": 6,
    "G-": 7,
    "G#": 8,
    "A-": 9,
    "A#": 10,
    "B-": 11,
}

opcodes = {
    # 0: "end of frame / loop frame"
    # 1 - 9A: notes (other than A-0)

    # +1: (.n vol | .n wait)
    "tie": 0x9B,

    # 9C-9F: unused.

    # +2: (.b pitch, .n vol | .n wait)
    "continue-pitch": 0xA0, # "slur"

    # +0
    "cut": 0xA0, #A1-AF... lower nibble = wait

    # +1: (.n vol | .n wait)
    "release": 0xB0,

    # +2 (.w addr)
    "groove": 0xB1,

    # +1 (.n alt | .n main)
    "volume": 0xB2,

    # +1 (.b pitch)
    "detune": 0xB3,

    # +1 (.n y | .n x)
    "arpxy": 0xB4,

    # +2 (.w addr)
    "vibrato": 0xB5,

    # +0
    "vibrato-cancel": 0xB6,

    # +1 (.1 %1 | .3 speed | .1 negate | .3 shift)
    "sweep": 0xB7,

    # +0
    "sweep-cancel": 0xB8,

    # TODO
    "length-counter": 0xB9,

    # TODO
    "linear-counter": 0xBA,

    # +1 (.b rate)
    "portamento": 0xBB,

    # +1 (.n vol | .n wait)
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

# converts octave and note class to note value
# e.g. 0, 9 -> 0
def get_note_value_from_octave_and_note(octave, note):
    return octave * 12 + note - get_note_value_from_str("A-0")

# extra track data created at preprocess time
track_data = []

def preprocess_tracks():
    for track_idx, track in enumerate(ft["tracks"]):
        data = {
            "name": track["title"],
            "patterns": [],
            "canonical-phrase-list": [], # contains tuples (channel, phrase-idx) ordered as they appear in the song. Allows iteration over phrases in correct process-order.
            "channels": [{
                # ft instruments used
                "instr_f": set(),
                # map: ft instrument idx -> data instrument idx
                "instr_fd": dict(),
                # map: data instrument idx -> ft instrument idx
                "instr_df": dict()
            } for i in range(NUM_CHANS)]
        }
        track_data.append(data)
        for pattern_idx in track["patterns"]:
            pattern_data = {
                "channels": []
            }
            data["patterns"].append(pattern_data)
            pattern = track["patterns"][pattern_idx]
            for chan_idx, chan in enumerate(pattern):
                channel_phrase_data = {
                    "rows": [],
                    "prev-phrases": set(), # phrases which come immediately before this phrase. -1 means the phrase is a starting phrase
                    "used": False, # is this phrase used at all in the track?
                    "lengths": set(), # the lengths of the patterns this phrase appears in
                }
                channel_data = data["channels"][chan_idx]
                
                pattern_data["channels"].append(channel_phrase_data)
                for row_idx, row in enumerate(chan):
                    row_data = {
                        "effects": []
                    }
                    if row["instr"] is not None and row["instr"] != "&&":
                        instr = int(row["instr"], 16)
                        channel_data["instr_f"].add(instr)
                    channel_phrase_data["rows"].append(row_data)
        # determine canonical pattern order
        frames = track["frames"]
        for i, frame in enumerate(frames):
            pattern_length = track["patternLength"]
            for channel_idx, phrase_idx in enumerate(frame):
                phrase_data = data["patterns"][phrase_idx]["channels"][channel_idx]
                croplength = get_rows_in_phrase(track_idx, phrase_idx, channel_idx)
                if croplength is not None:
                    pattern_length = min(pattern_length, croplength)

                canonical = (channel_idx, phrase_idx)
                if canonical not in data["canonical-phrase-list"]:
                    data["canonical-phrase-list"].append(canonical)
                phrase_data["used"] = True
                
                # set previous phrase for next phrase
                if i < len(frames) - 1:
                    next_frame = frames[i + 1]
                    next_phrase_idx = next_frame[channel_idx]
                    assert phrase_idx < len(data["patterns"])
                    assert next_phrase_idx < len(data["patterns"])
                    next_phrase_data = data["patterns"][next_phrase_idx]["channels"][channel_idx]
                    next_phrase_data["prev-phrases"].add(phrase_idx)
                if i == 0:
                    phrase_data["prev-phrases"].add(-1)
            # append to "lengths" for each pattern
            for channel_idx, phrase_idx in enumerate(frame):
                data["patterns"][phrase_idx]["channels"][channel_idx]["lengths"].add(pattern_length)

        # TODO: identify channels which can use the same instruments and phrases,
        # then merge their channel structs
        for channel in data["channels"]:
            assert len(channel["instr_f"]) <= NUM_INSTRS, "too many instruments on channel" + error_context(track= track_idx, channel= channel)
            # assign instrument idxs
            empty_instrument_found = False
            for data_idx, ft_idx in enumerate(channel["instr_f"]):
                # check that instrument actually exists in ft; otherwise,
                # assign to data_idx $F
                if ft_idx >= len(ft["instruments"]):
                    empty_instrument_found = True
                    channel["instr_fd"][ft_idx] = 0xF
                elif ft_idx == 0xF and empty_instrument_found:
                    assert False
                else:
                    channel["instr_fd"][ft_idx] = data_idx
                    channel["instr_df"][data_idx] = ft_idx


def make_phrase_data(song_idx, chan_idx, pattern_idx):
    track = ft["tracks"][song_idx]
    pattern = track["patterns"][pattern_idx]
    phrase = pattern[chan_idx]
    loop_point = 1
    data = [1] # (loop point -- can be rewritten later)
    
    # output state
    state_instr = None
    state_vol = None
    if chan_idx == NSE_TRI:
        state_vol = 1
    state_echo_vol = None
    state_echo_vol_pending_addr = -1
    state_note = None
    state_sweep = False
    echo_buffer = []

    # preprocesser channel data
    channel_pdata_phrase = track_data[song_idx]["patterns"][pattern_idx]["channels"][chan_idx]
    channel_pdata = track_data[song_idx]["channels"][chan_idx]
    assert channel_pdata_phrase["used"] # should not process unused phrase

    # determine previous phrase data
    prev_phrase_idxs = channel_pdata_phrase["prev-phrases"]
    phrase_info = ""
    if -1 in prev_phrase_idxs:
        phrase_info = "phrase appears at the start of the track"
    else:
        prev_phrases = [track_data[song_idx]["patterns"][idx]["channels"][chan_idx] for idx in prev_phrase_idxs]
        # get common suffix of echo buffer
        if len(prev_phrase_idxs) == 0:
            phrase_info = "no previous phrases identified"
        elif len(prev_phrase_idxs) == 1:
            prev_phrase_idx = list(prev_phrase_idxs)[0]
            prev_phrase = prev_phrases[0]
            phrase_info = "exactly one previous phrase; idx " + str(prev_phrase_idx)
            if "echo-buffer" not in prev_phrase:
                phrase_info += ", but has no echo buffer data"
            else:
                echo_buffer = prev_phrase["echo-buffer"]
        else:
            phrase_info = str(len(prev_phrase_idxs)) + " previous phrases identified"
            done = False
            for i in range(100): # get up to 100 previous echo buffer entries
                if done:
                    break

                # identify common echo buffer value
                echo_v = None
                for prev_phrase_idx, prev_phrase in zip(prev_phrase_idxs, prev_phrases):
                    if "echo-buffer" not in prev_phrase:
                        done = True
                        phrase_info += ", but phrase idx " + str(prev_phrase_idx) + " has no echo buffer"
                        break
                    else:
                        prev_echo_buffer = prev_phrase["echo-buffer"]
                        if i >= len(prev_echo_buffer):
                            phrase_info += "and phrase idx's echo buffer limits to only " + str(len(prev_echo_buffer)) + " values"
                            done = True
                            break
                        else:
                            prev_echo_v = prev_echo_buffer[-i - 1]
                            if echo_v is None:
                                echo_v = prev_echo_v
                            else:
                                if prev_echo_v != echo_v:
                                    phrase_info += ", but their echo buffers differ at end position " + str(i)
                                    done = True
                                    break
                if done:
                    break
                else:
                    echo_buffer = [echo_v] + echo_buffer

    # build phrase up to maximum length that it appears as in the track.
    phrase_len = max(list(channel_pdata_phrase["lengths"]))
    assert len(phrase) == track["patternLength"]

    wait_data = {
        "wait_idx": 0,
        "wait_byte_idx": 0,
        "state_cut": False
    }

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
        #preprocessor row data
        row_pdata = channel_pdata_phrase["rows"][row_idx]

        note = row["note"]
        instr = row["instr"]
        effects = row["effects"]
        ampersand = False
        if instr == "&&":
            instr = None
            ampersand = True
        elif instr is not None:
            instr = int(instr, 16)
            assert instr in channel_pdata["instr_fd"]
            instr = channel_pdata["instr_fd"][instr]

        if chan_idx == NSE_DPCM:
            vol = 0xF
        else:
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
                val = int(val, 16) + 1
                assert val - 1 < len(echo_buffer), "echo buffer overreach" + error_context(track= song_idx, channel= chan_idx, pattern= pattern_idx, row= row_idx) + "; " + (no_prev_phrase_reason if prev_phrase is None else "previous phrase is well-defined, but its echo buffer not long enough?")
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
        for effect in effects + row_pdata["effects"]:
            op = effect[0]
            args = effect[1:]
            argx = optional_hex(args)
            nibx = [optional_hex(args[0]), optional_hex(args[1])]
            if op == "B" or op == "D" or op == "C":
                assert early_break, "phrase end encountered but not early break!"
            elif op == "O":
                # set groove
                effect_applied = True
                out_byte(opcodes["groove"])
                data += [chunkptr(("groove", argx))]
            elif op == "P" and chan_idx not in [NSE_DPCM, NSE_NOISE]:
                # fine pitch
                # actually subtracts from pitch value, so the reciprocal value is applied
                out_byte(opcodes["detune"])
                out_byte(0x100 - argx)
                effect_applied = True
            elif op == "0" and chan_idx not in [NSE_DPCM]:
                # arpxy
                effect_applied = True
                out_byte(opcodes["arpxy"])
                # nibx[0] sets X and nibx[1] sets Y.
                # in the asm, we set Y from the high nibble:
                out_nibbles(nibx[1], nibx[0])
            elif op == "3" and chan_idx not in [NSE_DPCM, NSE_NOISE]:
                # portamento
                effect_applied = True
                out_byte(opcodes["portamento"])
                out_byte(argx)
            elif op == "4" and chan_idx not in [NSE_DPCM, NSE_NOISE]:
                # vibrato
                effect_applied = True
                assert chan_idx != NSE_NOISE, "noise channel does not support vibrato" + error_context(track= song_idx, channel= chan_idx, pattern= pattern_idx, row= row_idx)
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
            elif op == "H" or op == "I" and chan_idx not in [NSE_DPCM, NSE_NOISE]:
                # sweep
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
            elif effect[0:2] == "EE" and chan_idx not in [NSE_DPCM]:
                effect_applied = True
                # disable length/linear counter
                # TODO
                pass
            elif op == "E" and chan_idx not in [NSE_DPCM]:
                # alternative volume-set command
                if vol == None:
                    vol = argx
            elif op == "S" and chan_idx not in [NSE_DPCM]:
                # length/linear counter
                # TODO
                effect_applied = True
                pass
            elif op in ["W", "X", "Y", "Z"] and chan_idx == NSE_DPCM:
                # DPCM stuff
                pass
            elif op == "V" and chan_idx in NSE_SQ:
                effect_applied = True
                # TODO: set duty cycle
                pass
            elif op in ["G"]:
                print("WARNING: ignoring not-yet-implemented command: " + effect)
            else:
                assert False, "unrecognized command: " + effect + error_context(track= song_idx, channel= chan_idx, pattern= pattern_idx, row= row_idx)

        phrase_end = early_break or row_idx == len(phrase) - 1

        # DPCM channel has different basic commands than other channels, so we handle these separately.
        if chan_idx == NSE_DPCM:
            # set instrument (state)
            if instr is not None:
                state_instr = instr

            wait_amount = row_idx - wait_data["wait_idx"]

            dpcmkeys = ft["instruments"][channel_pdata["instr_df"][state_instr]]["dpcmkeys"] if state_instr is not None else {}
            dpcmkey = dpcmkeys.get(note + note_values["A-"], None) if note is not None else None

            if cut:
                out_nibbles(6, 0)
                set_wait(row_idx)
            elif release:
                out_nibbles(5, 0)
                set_wait(row_idx)
            elif dpcmkey is not None:
                # play a dpcm sample! :D
                pitch = dpcmkey["pitch"]
                label = ("dpcm", dpcmkey["index"])
                loop = dpcmkey["loop"]
                offset = dpcmkey["loopOffset"]
                delta = dpcmkey["delta"]
                length = dpcm_len4013[dpcmkey["index"]]

                # 1P opcode to play w/ pitch
                out_nibbles(4 if loop else 1, pitch)

                # single byte pointer to dpcm sample
                data.append(
                    chunkptr(label, mapping=lambda addr: [(addr >> 6) & 0xFF])
                )

                # sample length
                out_byte(
                    length
                )

                # $4011 write
                out_byte(delta if delta >= 0 else 0xFF)

                # offset and rest
                out_nibbles(offset, 0)
                set_wait(row_idx)
            elif (wait_amount >= MAX_WAIT_AMOUNT or row_idx == 0 or effect_applied) and not phrase_end:
                # note continue
                out_nibbles(3, 0)
                set_wait(row_idx)
        else:
            # select write volume if it has changed
            vol_change = False
            prev_vol = state_vol
            if vol is None and state_vol is None and note:
                # default to 0xF if vol and state_vol are none.
                vol = 0xF
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
                    assert False, "change of pitch and release not allowed simultaneously" + error_context(track= song_idx, channel= chan_idx, pattern= pattern_idx, row= row_idx)
                
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
                if vol_change or wait_data["state_cut"]:
                    if state_echo_vol == state_vol or state_echo_vol_pending_addr >= 0:
                        # swap in echo volume
                        echo = True

                        if state_echo_vol_pending_addr >= 0:
                            state_echo_vol = state_vol

                            # write echo vol at previous location
                            data[state_echo_vol_pending_addr] |= (state_echo_vol << 4)

                            state_echo_vol_pending_addr = -1

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
                assert state_instr != None, "cannot play note without setting instrument." + error_context(track=song_idx, channel= chan_idx, pattern= pattern_idx, row= row_idx)
                assert state_instr >= 0 and state_instr < 0x10, "instrument must be in range 0-F" + error_context(track= song_idx, channel= chan_idx, pattern= pattern_idx, row= row_idx)
                out_nibbles(state_instr, 0)
                set_wait(row_idx)
            elif vol_change:
                # change volume without any other effect.
                out_byte(opcodes["tie"])
                out_nibbles(state_vol, 0)
                set_wait(row_idx)
            elif (wait_amount >= MAX_WAIT_AMOUNT or row_idx == 0 or effect_applied) and not phrase_end:
                # just need to tie; no other changes.
                out_byte(opcodes["tie"])
                out_nibbles(0, 0)
                set_wait(row_idx)
            
        # this is the last row -- end loop and apply wait.
        if phrase_end:
            # end of phrase
            set_wait(row_idx + 1)
            if state_sweep:
                print("Warning: hardware sweep active at end of frame!")
            break
    channel_pdata_phrase["echo-buffer"] = echo_buffer
    data[0] = loop_point
    assert len(data) > loop_point
    assert data[loop_point] != 0 # this would cause an infinite loop
    return data + [0] # add end-of-phrase marker (loop end)

def make_vibrato_chunks():
    chunks = []
    for vibrato in vibrato_used:
        vibratostr = "4" + HX(vibrato[0]) + HX(vibrato[1])
        assert -0x80 not in vibrato_json[vibratostr]
        chunks.append(chunk(
            ("vibrato", vibrato[0], vibrato[1]),
            [
                v + 0x80 for v in vibrato_json[vibratostr]
            ] + [0]
        ))
    return chunks

def make_groove_chunks():
    grooves = ft["groove"]
    chunks = []
    for groove in grooves:
        assert 0 not in groove["data"]
        chunks.append(chunk(
            ("groove", groove["index"]),
            groove["data"] + [0] # add end marker
        ))
    return chunks

macro_packing = {
    "duty": 2,
    "vol": 2,
    "arp": 1,
    "arpmode": 1,
}

def make_macro_chunk(type, ft_macro, label, **kwargs):
    loop = ft_macro["loop"]
    release = ft_macro["release"]
    packing = macro_packing[type]

    # famitracker stores release at value minus one
    if release >= 0:
        release += 1

    # is there a release macro?
    has_release = release >= 0 and release < len(ft_macro["data"])

    # output chunk parameters
    chunkps = [
        {
            "label": label if i == 0 else (*label, "release"),

            # store release macro pointer before data
            "offset": 2,
            # ft_macro loop point
            # -1 means loop last value.
            # 0 means loop from first value on, etc.
            "loop": -1,
            # output data
            "data": [],
            # input 0cc macro data
            "ft_data": [],
            # alignment
            "align": 1,
            "alignoff": 0
        } for i in range(2 if has_release else 1)
    ]

    ft_macro_data = [*ft_macro["data"]]

    # split input data into release and base
    if has_release:
        chunkps[0]["ft_data"] = ft_macro_data[:release]
        chunkps[1]["ft_data"] = ft_macro_data[release:]
        if loop >= 0:
            if loop >= release:
                chunkps[1]["loop"] = loop - release
            if loop < release:
                chunkps[0]["loop"] = loop
    else:
        chunkps[0]["ft_data"] = ft_macro_data
        if loop >= 0:
            chunkps[0]["loop"] = loop
            
    for is_release, chunkp in enumerate(chunkps):
        ft_data = [*chunkp["ft_data"]] # input data (copy)
        assert len(ft_data) >= 0

        data = [] # output data
        ft_loop = chunkp["loop"]
        has_loop = ft_loop >= 0

        # ignore loop point if the looping section repeats one value only.
        if has_loop and len(set(ft_data[ft_loop:])) <= 1:
            has_loop = False
            ft_loop = -1

        # assert loop point and length aligns to packing
        if has_loop:
            # loop point is allowed to be arbitrary
            if ft_loop % packing != 0:
                print(f"WARNING: macro loop point not aligned to packing (x{packing})")
            if len(ft_data) % packing != 0:
                print(f"WARNING: length of macro not aligned to packing (x{packing})")

        if type in ["duty", "vol"]:
            for i, b in enumerate(ft_data):
                nibble = b
                if type == "duty":
                    nibble = (b << 2) | 3
                if type == "vol":
                    assert nibble != 0, "volume macro cannot contain 0." + error_context(type= type, label= label, **kwargs.get("context", {}))
                data += [nibble & 0xf]
        elif type in ["arp", "arpmode"]:
            arpset = ["absolute", "fixed", "relative", "scheme"][ft_macro["setting"]]
            chunkp["align"] = 2
            if arpset == "fixed":
                # support could be added, but where to store mode macro..?
                assert not "mode_macro" in kwargs, "fixed arp macros not available for noise channel" + error_context(type= type, label= label, **kwargs.get("context", {}))
                # fixed macros are distinguished from arp macros by
                # starting at an odd address
                chunkp["alignoff"] = 1
                for b in ft_data:
                    data += [b + 1]
                # add FF at end if non-looping and (this is release, or there is no release)
                if not has_loop:
                    if is_release or not has_release:
                        data += [0xFF]
            elif arpset == "relative":
                assert False, "relative pitch macros not supported" + error_context(type= type, label= label, **kwargs.get("context", {}))
            elif arpset in ["scheme", "absolute"]:
                mode_macro = None
                if "mode_macro" in kwargs and kwargs["mode_macro"] is not None:
                    mode_macro = kwargs["mode_macro"]
                    mode_loop = mode_macro["loop"]
                    mode_release = mode_macro["release"]
                    mode_data = mode_macro["data"]
                    if mode_loop != ft_macro["loop"]:
                        print("WARNING: mode/arp loop point does not match" + error_context(type= type, label= label, **kwargs.get("context", {})))
                    if mode_release != ft_macro["release"]:
                        print("WARNING: mode/arp release point does not match" + error_context(type= type, label= label, **kwargs.get("context", {})))
                    if len(mode_data) != len(ft_macro["data"]):
                        print("WARNING: mode/arp data lengths do not match" + error_context(type= type, label= label, **kwargs.get("context", {})))
                for i, b in enumerate(ft_data):
                    x = False
                    y = False
                    mode = False
                    if b < 0:
                        b += 0x100
                    assert b in range(0, 0x100)
                    if arpset == "scheme":
                        y = (b & 0x80) != 0
                        x = (b & 0x40) != 0
                        negative = (x and y)
                    else:
                        negative = b & 0x80 != 0
                        
                    
                    # convert to absolute form
                    if negative:
                        b -= 0x100
                        b = abs(b) & 0xFF
                        
                    if not x and not y and b == 0:
                        # prevents 0-byte.
                        negative = False

                    if mode_macro:
                        if is_release:
                            mode_data_i = i + mode_release
                            if i >= len(mode_data):
                                i = max(0, len(mode_data_i) - 1)
                        else:
                            mode_data_i = i
                            if i >= mode_release:
                                i = max(0, mode_release - 1)
                        mode = mode_data[mode_data_i] != 0
                        b &= 0xF

                    b &= 0x3F
                    # note that x and y are swapped from FT's format
                    # also note that negative is swapped as well
                    if x:
                        b |= 0x80
                    if y:
                        b |= 0x40
                    if not negative and not x and not y:
                        b |= 0xC0
                    if mode:
                        b |= 0x20
                    assert(b != 0)
                    data += [b]
        else:
            # no support for other macros yet.
            assert False

        assert 0 not in data, "macros cannot contain 0" + error_context(type= type, label= label, **kwargs.get("context", {}))
        # add loop point to release
        loop = 0
        loop_packing_offset = 0
        if ft_loop < 0:
            # loop to end
            loop = len(data) - 1
        
        assert len(data) > 0, "empty macro?!" + error_context(type=type, label=label, ft_macro=ft_macro, is_release=is_release)
        assert (loop >= 0)
        assert len(data) > loop, "loop point overruns macro data!"

        # loop the looping region if necessary to fix macro packing
        entries_added = 0
        while len(data) % packing != 0 or loop % packing != 0:
            if len(data) % packing != 0 and (len(data) - loop) % packing == 0:
                assert False, "loop region cannot be repeated to fix macro alignment; macro length or loop point needs to be adjusted."
            
            append = data[loop:]
            data = data + append
            entries_added += len(append)
            if loop % packing != 0:
                loop += len(append)

        bytes_added = (entries_added + packing - 1) // packing
        if bytes_added >= 2:
            print(f"WARNING: {bytes_added} bytes were appended to the macro in order to fix macro alignment")


        # if packing >= 2, pack array (into nibbles or bit-pairs or bits, etc.)
        data = pack_array(data, packing)

        # prepend loop point, append loop marker (0).
        data = [(loop // packing) + 1] + data + [0]

        # prepend release macro ptr
        # (chunkp["offset"] set to 2 to account for this.)
        if has_release and not is_release:
            data = [chunkptr(*label, "release")] + data
        else:
            # null ptr
            data = [chunkptr()] + data
        
        # detune base value is stored before release ptr
        if type == "detune":
            chunkp["offset"] += 1
            data = [detune_base] + data

        # set output data
        chunkp["data"] = data
    
    return [
        chunk(
            chunkp["label"],
            chunkp["data"],
            0xff - chunkp["offset"],
            chunkp["offset"],
            align=chunkp["align"],
            alignoff=chunkp["alignoff"]
        )
        for chunkp in reversed(chunkps)
    ]

def make_macro_chunks():
    chunks = []
    for track_idx, track in enumerate(ft["tracks"]):
        for chan_idx in range(NUM_CHANS):
            channel_pdata = track_data[track_idx]["channels"][chan_idx]
            for instr_idx in range(NUM_INSTRS):
                if instr_idx >= len(channel_pdata["instr_f"]):
                    # instrument index unused by channel
                    continue
                assert instr_idx in channel_pdata["instr_df"]
                ft_instr_idx = channel_pdata["instr_df"][instr_idx]
                
                for macro_type in channel_macros[chan_idx]:
                    label = ("song", track_idx, "channel", chan_idx, "instr", instr_idx, "macro", macro_type)
                    if ft_instr_idx >= len(ft["instruments"]):
                        # instrument not defined -- zerotable.
                        assign_chunk_to(
                            label, "null32"
                        )
                        continue
                    ft_instr = ft["instruments"][ft_instr_idx]
                    mtidx = ft_macro_type_idx[macro_type]
                    ft_macro_idx = ft_instr["macros"][mtidx]
                    if ft_macro_idx < 0 or (mtidx, ft_macro_idx) not in ft["macros"] or macro_type not in enabled_macros:
                        # no macro set.
                        chunks.append(
                            nullchunk(label)
                        )
                        continue
                    ft_macro = ft["macros"][(mtidx, ft_macro_idx)]
                    # add chunks
                    if macro_type == "arpmode":
                        ft_mode_type_idx = 4
                        ft_mode_macro_idx = ft_instr["macros"][ft_mode_type_idx]
                        if ft_mode_macro_idx < 0 or (ft_mode_type_idx, ft_mode_macro_idx) not in ft["macros"]:
                            ft_mode_macro = None
                        else:
                            ft_mode_macro = ft["macros"][(ft_mode_type_idx, ft_mode_macro_idx)]
                        # noise arp requires an additional macro
                        chunks += make_macro_chunk(macro_type, ft_macro, label, mode_macro=ft_mode_macro, context={"ft_macro_idx": ft_macro_idx, "ft_macro_type": mtidx, "ft_mode_macro_idx": ft_mode_macro_idx, "ft_mode_macro_type": ft_mode_type_idx})
                    else:
                        chunks += make_macro_chunk(macro_type, ft_macro, label, context={"ft_macro_idx": ft_macro_idx, "ft_macro_type": mtidx})

    return chunks

# $4013 length write for dpcm samples by idx
dpcm_len4013 = {}

def make_dpcm_chunks():
    chunks = []
    # produces dpcm samples, each in their own chunk.
    for dpcm_idx, dpcm in enumerate(ft["dpcm"]):
        data = dpcm["data"] + []
        dpcm_len4013[dpcm_idx] = int(max(0, len(dpcm["data"]) - 1) / 0x10)
        # pad sample with excess bytes until it becomes a multiple of 16 (or one more than)
        # (we should really always pad until it becomes one more than a multiple of 16,
        #  but then we lose the ability to pack samples nicely, so we sacrifice a single byte of DPCM
        #  garbage data to save 63 bytes of ROM.)
        while len(data) == 0 or len(data) % 0x10 > 1:
            data += [0xAA]
        chunks.append(chunk(
            ("dpcm", dpcm_idx),
            data,
            align=0x64,
            minaddr=0xC000,
            vbank=1
        ))
    return chunks

# indexed as listed in 0cc's exported .txt
phrase_chunks = dict()

def make_instr_chunks():
    chunks = make_macro_chunks()
    for track_idx, track in enumerate(ft["tracks"]):
        for chan_idx in range(NUM_CHANS):
            channel_pdata = track_data[track_idx]["channels"][chan_idx]
            for instr_idx in range(NUM_INSTRS):
                instr_label = ("song", track_idx, "channel", chan_idx, "instr", instr_idx)
                if instr_idx >= len(channel_pdata["instr_f"]):
                    # no such instrument
                    chunks.append(nullchunk(instr_label))
                    continue
                # table of macro addresses
                instrument = [
                    chunkptr("song", track_idx, "channel", chan_idx, "instr", instr_idx, "macro", macro_type)
                    for macro_type in channel_macros[chan_idx]
                ]
                chunks.append(chunk(
                    instr_label,
                    instrument
                ))
    return chunks

def make_phrase_chunks():
    chunks =  []
    for track_idx, track in enumerate(ft["tracks"]):

        # process phrases in canonical order
        for chan_idx, pattern_idx in track_data[track_idx]["canonical-phrase-list"]:
            pattern = track["patterns"][pattern_idx]
            data = make_phrase_data(track_idx, chan_idx, pattern_idx)
            label = ("song", track_idx, "channel", chan_idx, "phrase", pattern_idx)
            chunks.append(chunk(
                label,
                data
            ))
            assert(is_chunk(chunks[-1]))
    return chunks

def debug_macro_data(macro):
    s = ""
    for i, v in enumerate(macro["data"]):
        if i == macro["loop"] and i == macro["release"]:
            s += "->|"
        elif i == macro["loop"]:
            s += "| "
        elif i == macro["release"]:
            s += "-> "
        if v < 0:
            v += 0x100
        s += HX(v, 2) + " "
    return s

def print_debug_info():
    print("\n-----------")
    def _(n=0): # indent function
        return "  " * n
    print("tracks: ", len(track_data))
    for i, track in enumerate(track_data):
        print(f"  track {i}: {track['name']}")
        for ch_idx, channel in enumerate(track["channels"]):
            if len(channel["instr_df"]) > 0:
                print(f"{_(1)}Channel {CHANNEL_NAMES[ch_idx]}:")
                for instr_idx in channel["instr_df"]:
                    ft_instr_idx = channel["instr_df"][instr_idx]
                    ft_instr = ft["instruments"][ft_instr_idx]
                    print(f"{_(2)}Instr {instr_idx}; ft: {ft_instr_idx}, \"{ft_instr['name']}\"")
                    #(f"{_(3)}Type {ft_instr['type']}") # INSTR2A03, etc.
                    for macro_type_idx, macro_idx in enumerate(ft_instr['macros']):
                        if macro_idx != -1:
                            macro = ft["macros"][(macro_type_idx, macro_idx)]
                            print(f"{_(3)}Macro {macro_names[macro_type_idx]}; ft: {macro_idx}." \
                                + f"{' Type '  +macro['settingName'] if 'settingName' in macro else ''}")
                            print(f"{_(4)}ft macro: " + debug_macro_data(macro))
        print(f"  unique phrase count: ", len(track["canonical-phrase-list"]))
        print(f"  patterns: ", len(track["patterns"]))
        #for j, pattern in enumerate(track["patterns"]):
        #    print(f"    pattern {j}:")
        #    for channel in pattern["channels"]:
    print("-----------\n")

def ft_to_data(path):
    global ft
    ft = ftParseTxt(path)

    # sometimes we need a pointer to an "empty" chunk (a chunk with, say, 32 zeroes).
    chunks = [
        chunk("null32", [0] * 32)
    ]

    preprocess_tracks()

    # TODO: dpcm samples should come later.
    chunks += make_dpcm_chunks()

    chunks += make_instr_chunks() + make_phrase_chunks()

    chunks = make_vibrato_chunks() + make_groove_chunks() + chunks
    chunks += [
        # instruments and phrases per channel (per track)
        *[channel_chunk(i, j) for i in range(len(ft["tracks"])) for j in range(NUM_CHANS)],
        # channels and frames per track
        *[song_chunk(i) for i in range(len(ft["tracks"]))],
        # list of tracks
        chunk("song_table", [
            chunkptr(("song", i))
            for i in range(len(ft["tracks"]))
        ])
    ]
    
    print_debug_info()

    return chunks

def get_lua_symbols():
    lua = ""
    for track_idx, track in enumerate(track_data):
        lua += "tracks = {}\n"
        trackv = f"tracks[{track_idx + 1}]"
        lua += trackv + " = {}\n"
        lua += f"{trackv}.name = \"{track['name']}\"\n"
        lua += trackv + ".channels = {}\n"
        for channel_idx, channel in enumerate(track["channels"]):
            lua += f"{trackv}.channels[{channel_idx + 1}] = " + "{}\n"
            for instr_idx in channel["instr_df"]:
                instr_f_idx = channel["instr_df"][instr_idx]
                lua += f"{trackv}.channels[{channel_idx + 1}][{instr_idx + 1}] = " + "{}\n"
                lua += f"{trackv}.channels[{channel_idx + 1}][{instr_idx + 1}].name = \"{ft['instruments'][instr_f_idx]['name']}\"\n"
                
    return lua

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

