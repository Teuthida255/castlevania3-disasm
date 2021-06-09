-- assertions that the lua debugger can verify while the game is running
luasrt = {}

-- assert false
function luasrt.FALSE(addr)
  return false
end

-- assert register A is 0
function luasrt.A0(addr)
  return rA() == 0
end

-- assert register X is 0
function luasrt.X0(addr)
  return rX() == 0
end

-- assert register Y is 0
function luasrt.Y0(addr)
  return rY() == 0
end

-- assert at least of of register A and register Y is not 0
function luasrt.A_OR_Y_NONZERO(addr)
  return rY() ~= 0 or rA() ~= 0
end

-- assert Z flag set
function luasrt.BEQ(addr)
  return rZ()
end

-- assert Z flag clear
function luasrt.BNE(addr)
  return not rZ()
end

-- assert X equals whatever is stored in wChannelIdx_a1/wChannelIdx
function luasrt.X_IS_CHAN_IDX()
  local chan_idx = ram_read_byte_by_name("wChannelIdx_a1")
  return rX() == chan_idx
end

-- assert Y equals whatever is stored in wChannelIdx_a1/wChannelIdx
function luasrt.Y_IS_CHAN_IDX()
  local chan_idx = ram_read_byte_by_name("wChannelIdx_a1")
  return rY() == chan_idx
end

function register_asserts()
  for symbol, addr in pairs(g_symbols_ram) do
    local found, end_idx = symbol:find("_LUASRT_")
    if found ~= nil then
      local assertion_name = symbol:sub(end_idx + 1)
      local assertion_function = luasrt[assertion_name]
      if assertion_function == nil then
        emu.print("unrecognized assertion function: " .. assertion_name)
      else
        local bank = g_symbols_ram_bank[symbol]
        memory.registerexec(addr,
          function (addr)
            if get_bank_at_addr(addr) == bank then
              if assertion_function(addr) == false then
                local msg = "ASSERTION FAILED: " .. assertion_name .. " at address " .. HX(bank) .. ":" .. HX(addr, 4)
                emu.print(msg)
                emu.message(msg)
                debugger.hitbreakpoint()
              end
            end
          end
        )
      end
    end
  end
end