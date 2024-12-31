-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('reaper.gutil_os')

---@class Cmd
Cmd = {}

---@param url string
function Cmd.OpenURL(url)
    local command <const> = Os.IsMac() and 'open "" "' .. url .. '"' or 'start "" "' .. url .. '"'
    os.execute(command)
end