-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('Reaper.gutil_config')

---@class Debug
Debug = {
    enabled = Config("debug"):ReadBool("enabled")
}

---@param str string
---@param ... unknown
function Debug.Log(str, ...)
    if not Debug.enabled then return end
    reaper.ShowConsoleMsg(string.format(str, ...)) -- simple always on logging
end

return Debug