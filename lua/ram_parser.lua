-- functions for reading domain-specific info from ram

function channel_is_square(ch_idx)
  return ch_idx <= 1 or ch_idx >= 5
end

function macro_is_null(macroAddr)
  return memory.readwordunsigned(macroAddr) == 0
end

-- gets register A
function rA()
  return memory.getregister("a")
end

-- gets register X
function rX()
  return memory.getregister("x")
end

-- gets register Y
function rY()
  return memory.getregister("y")
end

-- gets status register
function rStatus()
  return memory.getregister("p")
end

-- gets Zero flag set
function rZ()
  return bit.band(rStatus(), 0x02) ~= 0
end

-- gets Negative flag set
function rN()
  return bit.band(rStatus(), 0x80) ~= 0
end

-- gets Carry flag set
function rC()
  return bit.band(rStatus(), 0x01) ~= 0
end

-- returns bankswitch register governing given ram address
-- (always in range 0x5113 - 0x5117 inclusive)
function get_mmc5_bankswitch_reg(addr)
  local prg_mode = bit.band(memory.readbyteunsigned(0x5100), 0x3)
  assert(addr >= 0x6000 and addr <= 0xffff)

  -- RAM register always in this range
  if (addr < 0x8000) then
    return 0x5113
  end

  if prg_mode == 0 then
  elseif prg_mode == 1 then
  elseif prg_mode == 2 then
  elseif prg_mode == 3 then
    assert(false)
  end
end

-- 0x5100
mmc5_bytes = {}
mmc5_bytes[0x5100] = 3
mmc5_bytes[0x5113] = 0xff
mmc5_bytes[0x5114] = 0xff
mmc5_bytes[0x5115] = 0xff
mmc5_bytes[0x5116] = 0xff
mmc5_bytes[0x5117] = 0xff

function mapper_write_cb(addr, size, value)
  --emu.print(hx(addr, 4) .. " <- " .. hx(value))
  mmc5_bytes[addr] = value
end

g_instr_idx_by_channel = {-1, -1, -1, -1, -1, -1, -1}

function break_on_set_instr(addr)
  -- guard for bank
  if get_bank_at_addr(addr) == g_symbols_ram_bank["nse_exec_readInstrWait@setInstr"] then
    -- get channel idx and accumulator value (containing instrument)
    local chan_idx_a1 = ram_read_byte_by_name("wChannelIdx_a1")
    if chan_idx_a1 >= 1 and chan_idx_a1 <= CHANNEL_COUNT then
      local a = memory.getregister("a")
      local instr_idx = bit.rshift(bit.band(a, 0x1e), 1)

      if chan_idx_a1 == 1 then
        --emu.print("channel " .. HX(chan_idx_a1 - 1) .. " instr " .. instr_idx)
        --debugger.hitbreakpoint()
      end

      g_instr_idx_by_channel[chan_idx_a1] = instr_idx
    else
      emu.print("invalid register")
      debugger.hitbreakpoint()
    end
  end
end

function register_watchpoints()
  -- mapper watchpoints
  memory.registerwrite(0x5100, mapper_write_cb)
  memory.registerwrite(0x5113, 5, mapper_write_cb)

  -- instrument set watchpoing
  if TRACK_CHANNEL_INSTRUMENT then
    memory.registerexec(g_symbols_ram["nse_exec_readInstrWait@setInstrTAY"], break_on_set_instr)
  end
end

function get_bank_at_addr(addr)
  if (addr < 0x6000) then return "w" end
  if (addr < 0x8000) then return "w" end -- mmc5 ram extension
  local prg_mode = mmc5_bytes[0x5100]
  local slot = 0x5113
  local offset = 0
  if prg_mode == 0 then
    slot = math.floor((addr - 0x8000) / 0x2000) + 0x5114
    offset = (addr % 0x2000)
  elseif prg_mode == 1 then
    if addr < 0xC000 then
      slot = 0x5115
      offset = (addr - 0x8000)
    elseif addr < 0xE000 then
      slot = 0x5116
      offset = (addr - 0xC000)
    else
      slot = 0x5117
      offset = (addr - 0xE000)
    end
  elseif prg_mode == 2 then
    if addr < 0xC000 then
      slot = 0x5115
      offset = (addr - 0x8000)
    else
      slot = 0x5117
      offset = (addr - 0xC000)
    end
  elseif prg_mode == 3 then
    slot = 0x5117
    offset = (addr - 0x8000)
  end
  bank_offset = math.floor(offset / 0x2000)
  return bit.band(mmc5_bytes[slot], 0x7f) + bank_offset
end

function ram_bank_loaded_for_symbol(name)
  return g_symbols_ram_bank[name] == get_bank_at_addr(g_symbols_ram[name])
end

function ram_read_byte_by_name(name, offset)
  offset = offset or 0
  local addr = g_symbols_ram[name]
  assert(addr ~= nil, "unknown symbol: " .. name)
  return memory.readbyteunsigned(addr + offset)
end

-- name: name of address for lo byte (or address of little-endian word if name_hi is nil)
-- name_hi: name of address for hi byte
-- offset: added to lo- and hi- address. If name_hi is not supplied, then offset is doubled
-- (as two-byte words are being read.)
function ram_read_word_by_name(name, name_hi, offset)
  name_hi = name_hi or nil
  offset = offset or 0
  local addr = g_symbols_ram[name]
  assert(addr ~= nil, "unknown symbol: " .. name)
  if name_hi == nil then
    -- read little-endian word
    return memory.readwordunsigned(addr + 2 * offset)
  else
    -- read two bytes in random access.
    local addr_hi = g_symbols_ram[name_hi]
    assert(addr_hi ~= nil, "unknown symbol: " .. name_hi)
    return memory.readwordunsigned(addr + offset, addr_hi + offset)
  end
end

function ram_read_words(addr_lo, addr_hi, size, stride)
  addr_hi = addr_hi or (addr_lo + 1)
  stride = stride or tern(addr_hi == addr_lo + 1, 2, 1)
  local t = {}
  for i = 1,size do
    t[i] = memory.readwordunsigned(addr_lo + i * stride, addr_hi + i * stride)
  end
  return t
end

function rom_read_words(addr_lo, addr_hi, size, stride)
  addr_hi = addr_hi or (addr_lo + 1)
  stride = stride or tern(addr_hi == addr_lo + 1, 2, 1)
  local t = {}
  for i = 1,size do
    t[i] = rom.readwordunsigned(addr_lo + i * stride, addr_hi + i * stride)
  end
  return t
end

function get_rom_address_of_symbol(name)
  local addr = g_symbols_ram[name]
  local bank = g_symbols_ram_bank[name]
  assert(addr ~= nil and bank ~= nil, "symbol not found in rom: " .. name)
  return get_rom_address_from_ram_addr(addr, bank)
  
end

function get_rom_address_from_ram_addr(ram_addr, bank)
  local header_offset = 0x10
  return bank * 0x2000 + (ram_addr % 0x2000) + header_offset
end

function rom_read_byte_by_name(name, offset)
  offset = offset or 0
  local rom_addr = get_rom_address_of_symbol(name)
  return rom.readbyteunsigned(rom_addr + offset)
end

function rom_read_word_by_name(name, name_hi, offset)
  name_hi = name_hi or nil
  offset = offset or 0
  local lo = 0
  local hi = 0
  if name_hi == nil then
    -- assume little-endian
    lo = rom_read_byte_by_name(name, offset * 2)
    hi = rom_read_byte_by_name(name, offset * 2 + 1)
  else
    lo = rom_read_byte_by_name(name, offset)
    hi = rom_read_byte_by_name(name_hi, offset)
  end
  return bit.bor(lo, bit.lshift(hi, 8))
end

function rom.readwordunsigned(addr_lo, addr_hi)
  addr_hi = addr_hi or (addr_lo + 1)
  lo = rom.readbyteunsigned(addr_lo)
  hi = rom.readbyteunsigned(addr_hi)
  return bit.bor(lo, bit.lshift(hi, 8))
end

function macro_to_string_brief(macroAddr, noloop)
  local addr = memory.readwordunsigned(macroAddr)
  local offset = memory.readbyteunsigned(macroAddr + 2)
  if addr == 0 then
    return string.format("NULL+%02x", offset)
  end
  local rom_addr = get_rom_address_from_ram_addr(addr, NSE_BANK)
  local loop = rom.readbyteunsigned(rom_addr)
  local loopstr = ""
  if noloop then
      -- indicate loop point is 0, and that's special
      loopstr = " (@0*)"
  else
      if loop == 0 then
          -- loop point of 0 is an error, since the first macro data byte should be at index 1
          loopstr = " (@!!)"
      elseif loop >= 2 then
          loopstr = string.format(" (@%02x)", loop)
      end
      if addr == 0 then
          loopstr = " (--)"
      end
  end
  return string.format("%04x+%02x%s", addr, offset, loopstr)
end

function macro_tickertape(macroAddr, length, noloop)
  local addr = memory.readwordunsigned(macroAddr)
  if addr == 0 then
      return "--"
  end
  -- bank slot 0 only (this is where NSE_BANK loads to)
  if addr < 0x8000 or addr >= 0x9fff then
    return "??"
  end
  local rom_addr = get_rom_address_from_ram_addr(addr, NSE_BANK)
  -- current offset of macro value
  local offset = memory.readbyteunsigned(macroAddr + 2)
  local loop_point = rom.readbyteunsigned(rom_addr)
  local start_point = tern(noloop, 0, 1)
  local s = ""
  local lbound = math.max(math.floor(offset - length * 1 / 4), 0)
  for i = lbound, lbound + length - 1, 1 do
      local val = rom.readbyteunsigned(rom_addr + i)
      local k = "  "
      if i == loop_point and not noloop then
          if i == start_point then
              k = "@:"
          elseif i == offset then
              k = "@["
          elseif i == offset + 1 then
              k = "]@"
          else
            k = " @"
          end
      else
          if i == 0 and not noloop then
            k = " ^"
          elseif i == start_point then
              k = " :"
          elseif i == offset then
              k = " ["
          elseif i == offset + 1 then
              k = "] "
          end
      end

      if i == start_point then
          if i == offset then
              k = k .. "["
          else
              k = " " .. k
          end
      end

      s = s .. k .. string.format("%02x", val)
  end
  return s
end

-- returns string interpreting sound.info()
function interpret_registers(chan_idx_a1, info)
  local vol = math.clamp(math.round(info.volume * 0xf), 0, 0xf)
  local notestr = hz_to_key(info.frequency)
  local duty = info.duty
  return "V:" .. hx(vol, 1) .. " D" .. tostring(info.duty) .. " " .. notestr
end

function display_stat(title, varname, chan_idx_a1)
  local extra = ""
  local value = ram_read_byte_by_name(varname, chan_idx_a1 - 1)
  if title == "pitch" or title == "p" then
    extra = " (" .. note_to_key(value) .. ")"
  end
  return title .. ":" .. HX(value, 2) .. extra
end

function interpret_cached_registers(chan_idx_a1)
  local channel_name = CHANNEL_NAMES[chan_idx_a1]
  if channel_is_square(chan_idx_a1 - 1) then
    -- read cached registers
    local r_vol = ram_read_byte_by_name("wMix_CacheReg_" .. channel_name .. "_" .. "Vol")
    local r_lo = ram_read_byte_by_name("wMix_CacheReg_" .. channel_name .. "_" .. "Lo")
    local r_hi = ram_read_byte_by_name("wMix_CacheReg_" .. channel_name .. "_" .. "Hi")
    local vol = bit.band(r_vol, 0x0f)
    local duty = bit.rshift(bit.band(r_vol, 0xc0), 6)
    local halt = bit.band(r_vol, 0x20) == 0x20
    local constant = bit.band(r_vol, 0x10) == 0x10
    local timer = bit.bor(bit.band(r_hi, 0x07) * 256, r_lo)
    local lcl = bit.rshift(bit.band(r_hi, 0xf8), 3)

    -- volume
    local s = "V:" .. HEX(vol, 1) .. " "

    -- flags and duty cycle
    s = s .. tern(halt, "H", "")
    s = s .. tern(constant, "C", "")
    s = s .. "D" .. tostring(duty) .. " "

    -- length counter (load)
    s = s .. "L:" .. HX(lcl) .. " "

    -- timer/pitch
    s = s .. "T:" .. HX(timer, 3) .. "/" .. hz_to_key(timer_to_hz(timer))

    return s
  end
  return nil
end

-- converts 15-bit pulse timer value to hz
function timer_to_hz(timer)
  return CPU_HZ / (16 * (timer + 1))
end

function hz_to_timer(f)
  return CPU_HZ / (16 * f) - 1
end

G_KEYNAMES = {
  "A-",
  "A#",
  "B-",
  "C-",
  "C#",
  "D-",
  "D#",
  "E-",
  "F-",
  "F#",
  "G-",
  "G#",
}

INV_LOG_TWO = 1 / math.log(2)

-- includes cents
function hz_to_key(f)
  local note_index = math.log(f / TUNING_A4_HZ) * INV_LOG_TWO * 12
  local note_index_round = math.floor(note_index + 0.5)
  local note_cents_offset = math.floor(100 * (note_index - note_index_round) + 0.5)
  return note_to_key(note_index_round + 4 * 12) .. tern(note_cents_offset >= 0, "+" .. tostring(note_cents_offset), tostring(note_cents_offset)) .. "c"
end

function note_to_key(n)
  if n == 0x4E then
    return "A-0"
  else
    local octave = math.floor((n + 9) / 12)
    local key_index_modulo = n % 12
    local key_name = G_KEYNAMES[key_index_modulo + 1]
    return key_name .. tern(octave >=0, tostring(octave), "?")
  end
end

-- sets tuning from ROM
function read_tuning()
  local timer_a4 = rom_read_word_by_name("nse_tuning_A4_lo", "nse_tuning_A4_hi")
  emu.print(hx(timer_a4, 4))
  TUNING_A4_HZ = timer_to_hz(timer_a4)
  emu.print(TUNING_A4_HZ)
  assert(TUNING_A4_HZ > 1) -- if hz <= 1, almost certainly this is a mistake.
end

function read_nse_bank()
  NSE_BANK = g_symbols_ram_bank["nse_emptySong"]
end

-- returns string describing instrument / channel table
function interpret_channel_instrument(chan_idx_a1)
  local s = ""

  -- get address of song
  local song_macro_addr = ram_read_word_by_name("wMacro@Song")


  if song_macro_addr == 0 then
    return "(No channel tables -- song is null.)\n"
  end

  -- get address of channel table
  -- (offset in song_t struct; see sounds.s)
  local song_rom_addr = get_rom_address_from_ram_addr(song_macro_addr, NSE_BANK)
  local channel_table_addr = rom.readwordunsigned(song_rom_addr + 1 + 2 * (chan_idx_a1 - 1))

  -- get address of cached channel table
  local channel_table_addr_cached = ram_read_word_by_name("wMusChannel_CachedChannelTableAddr", nil, chan_idx_a1 - 1)

  -- these should be the same, unless there is a bug.
  if channel_table_addr ~= channel_table_addr_cached then
    s = s .. "Mismatch table: " .. HX(channel_table_addr, 4) .. ", cache: " .. HX(channel_table_addr_cached, 4) .. " "
  else
    s = s .. "Table: " .. HX(channel_table_addr_cached, 4) .. " "
  end

  -- table is list of 0x10 pointers to instruments
  -- use cached, since that's what's actually in use.
  local channel_table_addr_rom = get_rom_address_from_ram_addr(channel_table_addr_cached, NSE_BANK)
  if g_instr_idx_by_channel[chan_idx_a1] >= 0 then
    assert(g_instr_idx_by_channel[chan_idx_a1] < 0x10)
    local instr_addr = rom.readwordunsigned(channel_table_addr_rom + 2 * g_instr_idx_by_channel[chan_idx_a1])
    if instr_addr ~= nil then
      local instr_addr_rom = get_rom_address_from_ram_addr(instr_addr, NSE_BANK)
      s = s .. "Instr " .. HX(instr_addr, 4) .. "\n"
      for macro_idx, macro in ipairs(CHANNEL_MACROS[chan_idx_a1]) do
        if macro ~= "Vib" then -- vibrato is not part of the instrument definition
          local macro_addr = rom.readwordunsigned(instr_addr_rom + 2 * (macro_idx - 1))

          -- Fixed macros replace Arp macros if address is odd
          if macro_addr % 2 == 1 then
            macro = "Fixed"
          end

          s = s .. macro:sub(1, 1) .. ":" .. HX(macro_addr, 4) .. " "
        end
      end
    else
      s = s .. "\n"
    end
  else
    s = s .. "\n"
  end
  return s
end

-- sets the locations wherein the wChannelIdx/wChannelIdx_a1 is to be interpreted as:
-- - 0-indexed (0=sq1), or
-- - 1-indexed ("a1" / 1=sq1), or
-- - spurious (neither)
g_chidx_0ranges = {}
g_chidx_1ranges = {}

function range_from_names(a, b)
  local addr_a = g_symbols_ram[a]
  local addr_b = g_symbols_ram[b]
  local bank = g_symbols_ram_bank[a]
  return {addr_a, addr_b, bank}
end

function initialize_channel_idx_ranges()
  g_chidx_0ranges = {
    range_from_names("NSE_MUSTICK_BEGIN","NSE_MUSTICK_END")
  }
  g_chidx_1ranges = {
    range_from_names("NSE_COMMANDS_BEGIN","NSE_COMMANDS_END")
  }
end

-- returns 0, 1, or nil (spurious)
function get_chidx_indexing_mode_from_addr(addr)
  local bank = get_bank_at_addr(addr)
  for _, range in g_chidx_0ranges do
    if bank == range[3] and addr >= range[1] and addr < range[2] then
      return 0
    end
  end

  for _, range in g_chidx_1ranges do
    if bank == range[3] and addr >= range[1] and addr < range[2] then
      return 1
    end
  end

  return nil
end

function verify_volume_table()
  local rom_addr = get_rom_address_of_symbol("volumeTable")
  assert(rom.readbyteunsigned(rom_addr) == 0)
  assert(rom.readbyteunsigned(rom_addr + 0x10) == 0)
  assert(rom.readbyteunsigned(rom_addr + 0x11) == 1)
  assert(rom.readbyteunsigned(rom_addr + 0x40) == 0)
  assert(rom.readbyteunsigned(rom_addr + 0xfe) == 0xe)
  assert(rom.readbyteunsigned(rom_addr + 0xef) == 0xe)
  assert(rom.readbyteunsigned(rom_addr + 0xff) == 0xf)
end

-- reads a byte from the given macro at the given position (including loop byte if applicable)
-- provide name of macro (e.g. "wMacro@Sq1_Vol")
-- (if position is not provided, read from current counter position instead.)
--
-- if 'allow_zero' is true, then zero will not be interpreted as the loop marker.
--
-- returns value and new position in macro.
function read_byte_from_macro(name, position, allow_zero)
  local macro_addr = ram_read_word_by_name(name)
  local macro_count = ram_read_byte_by_name(name, 2)
  local count = tern(position == nil, macro_count, position)
  
end