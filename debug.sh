set -e
echo "out..."
export CV3_DEBUG_LUA_ARGS="$@"
if [ ! -z "$NSE_DEBUG_VSCODE" ]
then
  eval $(luarocks path)
fi
fceux --loadlua nse.lua build/castlevania3build.nes