-- parses command line args or environment variable "CV3_DEBUG_LUA_ARGS"
require("util")

if arg == nil or arg == "" then
  local envargs = os.getenv("CV3_DEBUG_LUA_ARGS")
  if envargs ~= nil then
      arg = ". " .. envargs
  end
end
if arg ~= nil then
  if type(arg) == "string" then
      arg = split(arg)
  end
  if type(arg) == "table" then
      for i, a in ipairs(arg) do
          if i ~= 0 and a ~= nil and a ~= "" then
              if string.lower(a) == "--render" then
                  g_render = true
              end
              -- mute/solo channel data?
              for channel_idx, channel in ipairs(CHANNEL_NAMES) do
                  if string.lower("--mute-" .. channel) == string.lower(a) then
                      DISPLAY_CHANNELS[channel_idx] = false
                  end
                  if string.lower("--solo-" .. channel) == string.lower(a) then
                      g_channel = channel_idx - 1
                      for j = 1,#DISPLAY_CHANNELS do
                          DISPLAY_CHANNELS[j] = (j == channel_idx)
                      end
                  end
              end
          end
      end
  end
end