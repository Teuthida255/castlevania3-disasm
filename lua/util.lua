-- ternary if
function tern(c, t, f)
  if c then
      return t
  else
      return f
  end
end

function trace(...)
  s = ""
  args = {...}
  for i = 1, #args do
    if i ~= 1 then
      s = s .. " "
    end
    s = s .. tostring(args[i])
  end

  io.write(s .. "\n")
  emu.print(s)
end

function hx(v, k)
  k = k or 2
  if k == nil then
    return string.rep("?", k)
  end
  return string.format("%0" .. tostring(k) .. "x", v)
end

function HX(v, k)
  k = k or 2
  if k == nil then
    return string.rep("?", k)
  end
  return string.format("%0" .. tostring(k) .. "X", v)
end

function hex(v)
  return string.format("%x", v)
end

function HEX(v)
  return string.format("%X", v)
end

function maskshift(x, m, shift)
  if shift < 0 then
    return bit.lshift(bit.band(x, m), -shift)
  else
    return bit.rshift(bit.band(x, m), shift)
  end
end

-- tests
assert(hx(11) == "0b")
assert(HX(11) == "0B")
assert(maskshift(0x58, 0x50, 4) == 0x05)

-- https://stackoverflow.com/a/7615129
function split(inputstr, sep)
  if sep == nil then
      sep = "%s"
  end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
  end
  return t
end

function string.ulower(s)
  return s:sub(1, 1):upper() .. s:sub(2):lower()
end

function math.round(v)
  return math.floor(v + 0.5)
end

function math.clamp(x, a, b)
  return math.min(math.max(x, a), b)
end

-- https://stackoverflow.com/a/15434737
function isModuleAvailable(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == 'function' then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

function string.ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

function sign(x)
  if x == 0 then
    return 0
  elseif x > 0 then
    return 1
  else
    return -1
  end
end