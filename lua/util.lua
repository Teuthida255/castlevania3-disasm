-- ternary if
function tern(c, t, f)
  if c then
      return t
  else
      return f
  end
end

function hx(v, k)
  k = k or 2
  return string.format("%0" .. tostring(k) .. "x", v)
end

function HX(v, k)
  k = k or 2
  return string.format("%0" .. tostring(k) .. "X", v)
end

function hex(v)
  return string.format("%x", v)
end

function HEX(v)
  return string.format("%X", v)
end

-- tests
assert(hx(11) == "0b")
assert(HX(11) == "0B")

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
