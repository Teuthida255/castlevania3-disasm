-- verify nse_musTick works as intended.
--
-- breakpoint at start and end of each tick; calculated expected register output
-- at the start of the tick, then compare at the end.
--

VerifyTick = {}

function VerifyTick.watchpoint_nse_musTick(addr)
  -- at start of per-channel music tick, calculate expected values for end of tick
  if get_bank_at_addr(addr) == g_symbols_ram_bank["nse_musTick"] then
    local channel_idx = ram_read_byte_by_name("wChannelIdx")
    VerifyTick.calculateExpected(channel_idx)

    -- DEBUG / TEMP
    if g_frame_idx == -0x25 and channel_idx == CHAN_SQ3 then
      trace("frame", HX(g_frame_idx), "chan", channel_idx)
      debugger.hitbreakpoint()
    end
  end
end

function VerifyTick.watchpoint_compare(addr)
  if get_bank_at_addr(addr) == g_symbols_ram_bank["nse_updateSound@NSE_MUSTICK_COMPLETE"] then
    local channel_idx = ram_read_byte_by_name("wChannelIdx")
    local result = VerifyTick.compare(channel_idx)
    if result ~= nil and result ~= true then
      trace("frame " .. hx(g_frame_idx) .. ": channel " .. CHANNEL_NAMES[channel_idx + 1] .. " output unexpected: " .. tostring(result))
      debugger.hitbreakpoint()
    end
  end
end

function VerifyTick.register_watchpoints()
  memory.registerexec(g_symbols_ram["nse_musTick"], VerifyTick.watchpoint_nse_musTick)
  memory.registerexec(g_symbols_ram["nse_updateSound@NSE_MUSTICK_COMPLETE"], VerifyTick.watchpoint_compare)
end

g_calcs = {}

function nibble_from_parity(v, p)
  if p then
    return bit.rshift(bit.band(v, 0xf0), 4)
  else
    return bit.band(v, 0x0f)
  end
end

function multiply_volume(a, b)
  local combined = bit.bor(bit.band(a, 0x0f), bit.lshift(bit.band(b, 0x0f), 4))
  return rom_read_byte_by_name("volumeTable", combined)
end

function VerifyTick.calculateExpected(chan_idx)
  g_calcs[chan_idx + 1] = {}
  local calc = g_calcs[chan_idx + 1]

  if channel_is_square(chan_idx) then
    local macro_prefix = "wMacro@" .. CHANNEL_NAMES[chan_idx + 1] .. "_"

    local channel_bit = bit.lshift(1, chan_idx)
    local parity = bit.band(channel_bit, ram_read_byte_by_name("wMusChannel_ReadNibble")) ~= 0

    -- parity flips.
    calc.parity = not parity

    -- VOLUME ----------------------------------------------------------------
    -- base volume (crop out echo volume)
    local base_vol = ram_read_byte_by_name("wMusChannel_BaseVolume", chan_idx)
    base_vol = bit.band(base_vol, 0x0f)
    calc.base_vol = base_vol

    -- macro volume
    local macro_vol, macro_vol_idx = read_byte_from_macro(macro_prefix .. "Vol")
    
    if macro_vol == nil then
      macro_vol = 0xf
    else
      -- select nibble based on parity
      macro_vol = nibble_from_parity(macro_vol, parity)
    end

    -- multiply base and macro volume
    calc.macro_vol = macro_vol
    calc.vol = multiply_volume(macro_vol, base_vol)
    
    -- DUTY ----------------------------------------------------------------
    local macro_duty, macro_duty_counter = read_byte_from_macro(macro_prefix .. "Duty")
    if macro_duty == nil then
      -- read directly-stored duty cycle value
      macro_duty = ram_read_byte_by_name(macro_prefix .. "Duty", 2)
      calc.is_base_duty = true
    else
      macro_duty = nibble_from_parity(macro_duty, parity)
      calc.is_base_duty = false
    end

    calc.duty = maskshift(macro_duty, 0xC, 2)

    -- PORTAMENTO ----------------------------------------------------------
    local portrate = ram_read_byte_by_name("wMusChannel_portrate", chan_idx)
    calc.portrate = portrate

    -- NOTE ----------------------------------------------------------------
    local base_note = ram_read_byte_by_name("wMusChannel_BasePitch", chan_idx)
    calc.base_note = base_note
    if portrate ~= 0 then
      -- portamento and arp are mutually exclusive
      calc.note = calc.base_note
      calc.arptype = "portamento"
    else
      -- standard arpeggio
      local macro_arp, macro_arp_counter = read_byte_from_macro(macro_prefix .. "Arp")
      -- fixed macros are stored at odd addresses
      local macro_fixed = ram_read_word_by_name(macro_prefix .. "Arp") % 2 == 1
      if macro_arp == nil then
        macro_arp = 0x0
        calc.arptype = "none"
      end
      if macro_fixed then
        -- fixed macro
        calc.note = macro_arp
        calc.arptype = "fixed=" .. HX(macro_arp)
      else
        -- relative arp
        local chan_xy = ram_read_byte_by_name("wMusChannel_ArpXY", chan_idx)
        local chan_x = bit.band(chan_xy, 0x0f)
        local chan_y = bit.rshift(bit.band(chan_xy, 0xf0), 4)

        local sign = bit.rshift(bit.band(macro_arp, 0xC0), 6)
        local amount = bit.band(macro_arp, 0x3f)
        local macro_offset = 0
        if sign == 0x00 then
          macro_offset = -amount
        else
          macro_offset = amount + tern(sign == 1, chan_x, 0) + tern(sign == 2, chan_y, 0)
        end

        calc.note = math.max(base_note + macro_offset, 0)
        calc.arptype = "relative=" .. HX(macro_arp)
      end
    end

    -- FREQUENCY --------------------------------------------------------------
    local base_detune = ram_read_byte_by_name("wMusChannel_BaseDetune", chan_idx) - 0x80

    -- read (signed) detune accumulator value
    local base_detune_accumulator = ram_read_word_by_name("wMusChannel_DetuneAccumulator_Lo", "wMusChannel_DetuneAccumulator_Hi", chan_idx)
    if base_detune_accumulator >= 0x8000 then
      base_detune_accumulator = base_detune_accumulator - 0x10000
    end
    
    -- detune macro
    local detune_macro, detune_macro_counter = read_byte_from_macro(macro_prefix .. "Detune")
    assert(detune_macro == nil, "detune macros not supported yet.")
    local detune_macro_value = 0 -- TODO: read detune_macro's value.
    local detune_accumulator = base_detune_accumulator + detune_macro_value
    calc.detune_accumulator = detune_accumulator
    if detune_macro ~= nil then 
       -- base value stored 3 bytes before start as a reverse-signed 8-bit value
      calc.detune_macro_base_value = read_byte_from_macro(macro_prefix .. "Detune", -3) - 0x80
    else
      calc.detune_macro_base_value = 0
    end

    -- vibrato
    local vib_macro, vib_macro_idx = read_byte_from_macro(macro_prefix .. "Vib")
    local vib_offset = 0
    if vib_macro == nil then
      vib_offset = 0
    else
      vib_offset = vib_macro - 0x80
    end
    calc.vib_offset = vib_offset

    -- frequency
    local note_freq = pitch_lookup(calc.note)
    local play_freq = note_freq
    if portrate ~= 0 then
      -- portamento (automatic pitch slide) enabled.
      -- note_freq is the *target* note frequency for portamento.

      -- arp macro is reused to store saved portamento pitch instead
      local prev_port_freq = ram_read_word_by_name(macro_prefix .. "Arp")
      calc.prev_port_freq = prev_port_freq
      local new_port_freq = prev_port_freq
      if math.abs(prev_port_freq - note_freq) <= portrate then
        -- jump straight to target frequency, since we're close enough
        new_port_freq = note_freq
      else
        -- add to frequency instead.
        new_port_freq = prev_port_freq + sign(note_freq - prev_port_freq) * portrate
      end
      calc.port_freq = new_port_freq
      play_freq = new_port_freq
    end

    calc.freq = play_freq + vib_offset + detune_accumulator + base_detune + calc.detune_macro_base_value
  end
end

-- read the channel base values and audio registers and compare them to the set values.
function VerifyTick.compare(chan_idx)
  local calc = g_calcs[chan_idx + 1]
  if not calc then
    return
  end
  local chan_name = CHANNEL_NAMES[chan_idx + 1]
  local out = {} -- the actual cached registers set by the 6502
  if channel_is_square(chan_idx) then
    out.base_vol = bit.band(ram_read_byte_by_name("wMusChannel_BaseVolume", chan_idx), 0x0f)
    out.base_freq = ram_read_byte_by_name("wMusChannel_BasePitch", chan_idx)
    out.base_detune = ram_read_byte_by_name("wMusChannel_BaseDetune", chan_idx)
    out.detune_accumulator = ram_read_word_by_name("wMusChannel_DetuneAccumulator_Lo", "wMusChannel_DetuneAccumulator_Hi", chan_idx)
    out.arpxy = ram_read_byte_by_name("wMusChannel_ArpXY", chan_idx)
    out.portrate = ram_read_byte_by_name("wMusChannel_portrate", chan_idx)
    out.port_freq = ram_read_word_by_name("wMacro@" .. chan_name .. "_" .. "Arp") -- only valid if portrate ~= 0
    
    local channel_bit = bit.lshift(1, chan_idx)
    out.parity = bit.band(channel_bit, ram_read_byte_by_name("wMusChannel_ReadNibble")) ~= 0

    -- registers
    out.volreg = ram_read_byte_by_name("wMix_CacheReg_" .. chan_name .. "_Vol")
    out.lo = ram_read_byte_by_name("wMix_CacheReg_" .. chan_name .. "_Lo")
    out.hi = ram_read_byte_by_name("wMix_CacheReg_" .. chan_name .. "_Hi")
    out.vol = bit.band(out.volreg, 0x0F)
    out.duty = maskshift(out.volreg, 0xC0, 6)
    -- length counter flag
    out.lhalt = maskshift(out.volreg, 0x20, 5)
    -- constant volume flag
    out.cvol = maskshift(out.volreg, 0x10, 4)
    out.freq = bit.bor(out.lo, maskshift(out.hi, 0x07, -8))

    if out.base_vol ~= calc.base_vol then
      -- this would be strange; base volume isn't supposed to change.
      return "base volume mismatch: " .. HX(out.base_vol) .. ", expected " .. HX(calc.base_vol)
    end

    if out.parity ~= calc.parity then
      return "parity mismatch: " .. tostring(out.parity) .. ", expected " .. tostring(calc.parity)
    end

    if out.vol ~= calc.vol then
      return "volume mismatch: " .. HX(out.vol) .. ", expected " .. HX(calc.vol)
        .. " (macro vol: " .. HX(calc.macro_vol) .. "; base vol: " .. HX(calc.base_vol) .. ")"
    end

    if out.duty ~= calc.duty then
      return "duty cycle mismatch: " .. HX(out.duty) .. ", expected " .. HX(calc.duty)
        .. " (is base duty: " .. tostring(calc.is_base_duty) .. ")"
    end

    if out.detune_accumulator ~= calc.detune_accumulator then
      return "detune accumulator mismatch: " .. HX(out.duty) .. ", expected " .. HX(calc.duty)
    end

    if out.portrate ~= 0 and out.port_freq ~= calc.port_freq then
      return "portamento frequency mismatch: " .. HX(out.port_freq) .. ", expected " .. HX(calc.port_freq)
        .. " (portamento rate " .. HX(out.portrate) .. ")"
    end

    if out.freq ~= calc.freq then
      local errstr =  "frequency mismatch: " .. HX(out.freq) .. ", expected " .. HX(calc.freq)
      if out.portrate ~= 0 then
        errstr = errstr .. " (portamento pitch " .. HX(out.port_freq)
          .. "; prev portamento pitch " .. HX(calc.prev_port_freq)
          .. "; target portamento pitch " .. HX(pitch_lookup(calc.note))
          .. "; portamento rate " .. HX(out.portrate)
          .. "; base detune " .. HX(out.base_detune)
          .. "; vib offset " .. HX(calc.vib_offset + 0x80)
          .. "; macro base detune " .. HX(calc.detune_macro_base_value + 0x80)
          .. '; detune accumulator ' .. HX(out.detune_accumulator, 4)
          .. ")"
      else
        errstr = errstr
          .. " (pitch " .. HX(pitch_lookup(calc.note)) .. "<-" .. HX(calc.note)  .. " [" .. HX(pitch_lookup(calc.base_note)) .. "<-" .. HX(calc.base_note) .. "]"
          .. "; base detune " .. HX(out.base_detune)
          .. "; vib offset " .. HX(calc.vib_offset + 0x80)
          .. "; macro base detune " .. HX(calc.detune_macro_base_value + 0x80)
          .. '; detune accumulator ' .. HX(out.detune_accumulator, 4)
          .. '; arpeggio type ' .. calc.arptype
          .. ")"
      end

      return errstr
    end
  end

  return true
end