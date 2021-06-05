-- can parse and interpret pattern data into commands (as in code/newSoundEngineCommands.s)

-- interprets pattern starting at the given rom address
function interpret_pattern(chan_idx_a1, addr)

  local track_data = tracks[1]
  local channel_data = track_data.channels[chan_idx_a1]

  -- remember addr (we'll be editing it)
  base_addr = addr

  -- pattern loop point
  local loop_idx = rom.readbyteunsigned(addr)
  addr = addr + 1

  if CHANNEL_NAMES[chan_idx_a1] == "DPCM" then
    -- TODO
    return "[DPCM]"
  end

  -- parse opcodes
  local acc = "PATTERN (rom 0x" .. HEX(addr - 1, 4) .. ")\n"
  local done = false
  while not done do
    local s = ""
    local start_addr = addr
    local read_instr = nil
    local read_wait = nil

    -- read opcode
    local op = rom.readbyteunsigned(addr)
    addr = addr + 1

    -- parse specific opcode
    if op == 0 then
      -- end/loop
      done = true
      s = "===== loop ======"
    elseif op < 0x9b or op == 0xBC then
      -- note. (0xBC is an alias for 0, because 0 ends the pattern.)
      local note_op = tern(op == 0xBC, 0, op)
      local is_echo = note_op % 2 == 1
      local note = bit.rshift(note_op, 1)
      s = note_to_key(note)
      if is_echo then
        s = s ..  " echo"
      end
      
      -- instr and wait (two nibbles in one byte)
      local b = rom.readbyteunsigned(addr)
      addr = addr + 1
      read_instr = bit.rshift(bit.band(b, 0xf0), 4)
      read_wait = bit.rshift(bit.band(b, 0x0f), 0)
    elseif op == 0x9b then
      -- tie

      -- volume and wait (two nibbles in one byte)
      local b = rom.readbyteunsigned(addr)
      addr = addr + 1
      read_vol = bit.rshift(bit.band(b, 0xf0), 4)
      read_wait = bit.rshift(bit.band(b, 0x0f), 0)
    elseif op <  0xA0 then
      -- invalid
      s = "INVALID"
      done = true
    elseif op >= 0xB0 then
      -- effects
      
      if op == 0xb0 then
        -- release
        s = "release"

        -- volume and wait (two nibbles in one byte)
        local b = rom.readbyteunsigned(addr)
        addr = addr + 1
        read_vol = bit.rshift(bit.band(b, 0xf0), 4)
        read_wait = bit.rshift(bit.band(b, 0x0f), 0)
      elseif op == 0xb1 then
        -- groove
        s = "groove"

        local lo = rom.readbyteunsigned(addr)
        addr = addr + 1
        local hi = rom.readbyteunsigned(addr)
        addr = addr + 1
        local groove = bit.bor(bit.lshift(hi, 8), lo)
        s = s .. " " .. HX(groove, 4)
      elseif op == 0xb2 then
        -- volume
        local v = rom.readbyteunsigned(addr)
        addr = addr + 1
        s = "volume " .. HX(v)
      elseif op == 0xb3 then
        -- set base detune
        local v = rom.readbyteunsigned(addr)
        addr = addr + 1
        s = "base-detune " .. HX(v)
      elseif op == 0xb4 then
        -- set arpxy
        local v = rom.readbyteunsigned(addr)
        addr = addr + 1
        s = "arpxy " .. HX(v)
      elseif op == 0xb5 then
        -- set vibrato
        s = "vibrato"

        local lo = rom.readbyteunsigned(addr)
        addr = addr + 1
        local hi = rom.readbyteunsigned(addr)
        addr = addr + 1
        local groove = bit.bor(bit.lshift(hi, 8), lo)
        s = s .. " " .. HX(groove, 4)
      elseif op == 0xb6 then
        -- cancel vibrato
        s = "vibrato cancel"
      elseif op == 0xb7 then
        -- hardware sweep
        local v = rom.readbyteunsigned(addr)
        addr = addr + 1
        s = "sweep " .. HX(v)
      elseif op == 0xb8 then
        -- cancel hardware sweep
        s = "sweep cancel"
      elseif op == 0xb9 then
        -- length counter

        -- TODO
      elseif op == 0xba then
        -- linear counter

        -- TODO
      elseif op == 0xbb then
        -- portamento
        local v = rom.readbyteunsigned(addr)
        addr = addr + 1
        s = "portamento " .. HX(v)
      else
        s = "INVALID"
        done = true
      end
    elseif op == 0xA0 then
      -- slur

      -- read new note
      local n = rom.readbyteunsigned(addr)
      addr = addr + 1

      s = "slur " .. note_to_key(n)

      -- read vol and wait
      local b = rom.readbyteunsigned(addr)
      addr = addr + 1

      read_vol = bit.rshift(bit.band(b, 0xf0), 4)
      read_wait = bit.rshift(bit.band(b, 0x0f), 0)
    else -- (A0-AF)
      -- cut (1-F)
      s = "cut"
      read_wait = bit.band(op, 0xf)
    end

    -- read instrument (optional)
    if read_instr ~= nil and read_instr ~= 0 then
      s = s .. " instr:" .. HEX(read_instr)
      if channel_data[read_instr + 1] then
        s = s .. ' "' .. channel_data[read_instr + 1].name .. '"'
      end
    end

    if read_vol ~= nil and read_vol ~= 0 then
      s = s .. " vol:" .. HEX(read_vol)
    end

    if read_wait ~= nil then
      s = s .. " wait:" .. HEX(read_wait)
      if read_wait == 0 then
        s = s .. " [INVALID]"
      end
    end

    -- append bytes for this opcode
    if start_addr - base_addr == loop_idx then
      acc = acc .. "@ "
    else
      acc = acc .. "  "
    end
    for a = start_addr,addr - 1 do
      acc = acc .. HX(rom.readbyteunsigned(a)) .. " "
    end
    -- append string for this opcode.
    acc = acc .. "; " .. s .. "\n"
  end

  return acc
end