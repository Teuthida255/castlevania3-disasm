-- verify nse_musTick works as intended.
--
-- breakpoint at start and end of each tick; calculated expected register output
-- at the start of the tick, then compare at the end.
--

function VerifyTick.watchpoint_nse_musTickDPCM(addr)
  if get_bank_at_addr(addr) == g_symbols_ram_bank["nse_musTickDPCM"] then
    local channel_idx = ram_read_byte_by_name("wChannelIdx_a1")
    VerifyTick.calculateExpected(channel_idx)
  end
end

function VerifyTick.watchpoint_nse_musTickDPCM(addr)
  if get_bank_at_addr(addr) == g_symbols_ram_bank["nse_updateSound@NSE_MUSTICK_COMPLETE"] then
    local channel_idx = ram_read_byte_by_name("wChannelIdx_a1")
    local result = VerifyTick.compare(channel_idx)
    if result ~= nil and result ~= true then
      emu.print("channel " .. CHANNEL_NAMES[channel_idx + 1] .. " output unexpected: " .. tostring(result))
      debugger.hitbreakpoint()
    end
  end
end

function VerifyTick.register_watchpoints()
  memory.registerexec(g_symbols_ram["nse_musTickDPCM"], VerifyTick.watchpoint_nse_musTickDPCM)
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
  local combined = bit.bor(bit.band(a, 0x0f), bit.rshift(bit.band(b, 0x0f), 4))
  return rom_read_byte_by_name("volumeTable", combined)
end

function VerifyTick.calculateExpected(chan_idx)
  g_calcs[chan_idx + 1] = {}
  local calc = g_calcs[chan_idx + 1]

  if channel_is_square(chan_idx)
    local macro_prefix = "wMacro@" .. CHANNEL_NAMES[chan_idx + 1] .. "_"

    local channel_bit = bit.lshift(1, chan_idx)
    local parity = bit.band(channel_bit, ram_read_byte_by_name("wMusChannel_ReadNibble"))

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
      macro_vol = nibble_from_parity(macro_vol, not parity)
    end
    calc.macro_vol = macro_vol

    -- multiply base and macro volume
    calc.vol = multiply_volume(macro_vol, base_vol)
    
    -- DUTY ----------------------------------------------------------------
    local base_duty = ram_read_byte_by_name(macro_prefix .. "Duty")
    local macro_duty, macro_duty_counter = read_byte_from_macro(macro_prefix .. "Duty")
    if macro_duty == nil then
      macro_duty = base_duty
    else
      macro_duty = nibble_from_parity(macro_duty, parity)
    end
    calc.duty = bit.bor(macro_duty, 3)

    -- PORTAMENTO ----------------------------------------------------------
    local portrate = ram_read_byte_by_name("wMusChannel_portrate", chan_idx)
    calc.portrate = portrate

    -- NOTE ----------------------------------------------------------------
    local base_note = ram_read_byte_by_name("wMusChannel_BasePitch", chan_idx)
    calc.base_note = base_note
    if portrate ~= 0 then
      -- portamento and arp are mutually exclusive
      calc.note = calc.base_note
    else
      -- standard arpeggio
      local macro_arp, macro_arp_counter = read_byte_from_macro(macro_prefix .. "Arp")
      local macro_fixed = ram_read_word_by_name[macro_prefix .. "Duty"] % 2 == 1
      if macro_arp == nil then
        macro_arp = 0x0
      end
      if macro_fixed then
        -- fixed macro
        calc.note = macro_arp
      else
        -- relative arp
        local chan_xy = ram_read_byte_by_name("wMusChannel_ArpXY", chan_idx)
        local chan_x = bit.band(chan_xy, 0x0f)
        local chan_y = bit.rshift(bit.band(chan_xy, 0xf0), 4)

        local sign = bit.rshift(bit.band(macro_arp, 0xC0), 6)
        local amount = bit.band(macro_arp, 0x3f)
        local macro_offset = 0
        if sign == 0x3 then
          macro_offset = -amount
        else
          macro_offset = amount + tern(sign == 1, chan_x, 0) + tern(sign == 2, chan_y, 0)
        end

        calc.note = math.max(base_note + macro_offset, 0)
      end
    end

    -- PITCH --------------------------------------------------------------
    local base_detune = ram_read_byte_by_name("wMusChannel_BaseDetune", chan_idx) - 0x80

    -- read (signed) detune accumulator value
    local base_detune_accumulator = ram_read_word_by_name("wMusChannel_DetuneAccumulator_Lo", "wMusChannel_DetuneAccumulator_Hi", chan_idx)
    if base_detune_accumulator >= 0x8000 then
      base_detune_accumulator = base_detune_accumulator - 0x10000
    end

    -- detune macro
    local detune_macro, detune_macro_counter = read_byte_from_macro(macro_prefix .. "Detune")
    assert(detune_macro == nil, "detune macros not supported yet.")
    local detune_macro_value = 0
    local detune_accumulator = base_detune_accumulator + detune_macro_value
    calc.new_detune_accumulator = detune_accumulator

    -- vibrato
    local vib_macro, vib_macro_idx = read_byte_from_macro(macro_prefix .. "Vib")
    local vib_offset = 0
    if vib_macro == nil then
      vib_offset = 0
    else
      vib_offset = vib_macro - 0x80
    end

    -- pitch
    local anchor_pitch = pitch_lookup(calc.note)
    if portrate == 0 then
      -- portamento disabled.
      calc.pitch = anchor_pitch + vib_offset + detune_accumulator
    else
      -- portamento enabled.

      -- arp macro is reused to store saved portamento pitch instead
      local prev_port_pitch = ram_read_word_by_name(macro_prefix .. "Arp")
      local new_port_pitch = prev_port_pitch
      if math.abs(prev_port_pitch - anchor_pitch) <= portrate then
        new_port_pitch = anchor_pitch
      else
        new_port_pitch = prev_port_pitch + math.sign(anchor_pitch - prev_port_pitch) * portrate
      end
      calc.port_pitch = new_port_pitch
      calc.pitch = new_port_pitch + vib_offset + detune_accumulator
    end
  end
end

function VerifyTick.compare()
  return true
end