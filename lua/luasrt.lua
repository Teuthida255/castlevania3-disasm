-- assertions that the lua debugger can verify while the game is running
luasrt = {}

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