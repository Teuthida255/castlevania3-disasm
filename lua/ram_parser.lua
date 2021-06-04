-- functions for reading domain-specific info from ram

function channel_is_square(ch_idx)
  return ch_idx <= 1 or ch_idx >= 5
end

function macro_is_null(macroAddr)
  return memory.readwordunsigned(macroAddr) == 0
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

function register_mapper_watch()
  memory.registerwrite(0x5100, mapper_write_cb)
  memory.registerwrite(0x5113, 5, mapper_write_cb)
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

function get_rom_address_of_symbol(name)
  local addr = g_symbols_ram[name]
  local bank = g_symbols_ram_bank[name]
  assert(addr ~= nil and bank ~= nil, "symbol not found in rom: " .. name)
  local in_bank_addr = addr % 0x2000 -- address within the bank (range 0-0x1fff inclusive)
  local header_offset = 0x10
  return bank * 0x2000 + in_bank_addr + header_offset
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

function macro_to_string_brief(macroAddr, noloop)
  local addr = memory.readwordunsigned(macroAddr)
  local offset = memory.readbyteunsigned(macroAddr + 2)
  local loop = memory.readbyteunsigned(addr)
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
  if addr == 0 then
      return string.format("NULL+%02x%s", offset, loopstr)
  else
      return string.format("%04x+%02x%s", addr, offset, loopstr)
  end
end

function macro_tickertape(macroAddr, length, noloop)
  local addr = memory.readwordunsigned(macroAddr)
  if addr == 0 then
      return "--"
  end
  -- current offset of macro value
  local offset = memory.readbyteunsigned(macroAddr + 2)
  local loop_point = memory.readbyteunsigned(addr)
  local start_point = tern(noloop, 0, 1)
  local s = ""
  local lbound = math.max(math.floor(offset - length * 1 / 4), start_point)
  for i = lbound, lbound + length - 1, 1 do
      local val = memory.readbyteunsigned(addr + i)
      local k = "  "
      if i == loop_point and not noloop then
          if i == start_point then
              k = "@:"
          elseif i == offset then
              k = "@["
          elseif i == offset + 1 then
              k = "]@"
          end
      else
          if i == start_point then
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
function interpret_registers(chan_idx_a11, info)
  local vol = math.clamp(math.round(info.volume * 0xf), 0, 0xf)
  local notestr = hz_to_key(info.frequency)
  local duty = info.duty
  return "V:" .. hx(vol, 1) .. " D" .. tostring(info.duty) .. " " .. notestr
end

function display_stat(title, varname, chan_idx_a1, onscreen)
  local extra = ""
  local value = ram_read_byte_by_name(varname, chan_idx_a1 - 1)
  if title == "pitch" then
    extra = " " .. note_to_key(value)
  end
  print_fceux(title .. " " .. CHANNEL_NAMES[chan_idx_a1] .. ": " .. string.format("%02x", value) .. extra, onscreen)
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