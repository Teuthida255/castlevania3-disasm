
function hx(v)
  return string.format("%02x", v)
end

function HX(v)
  return string.format("%02X", v)
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