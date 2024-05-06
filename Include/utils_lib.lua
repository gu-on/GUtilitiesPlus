-- @version 1.1
-- @noindex

_INCLUDED = _INCLUDED or {}

dofile(debug.getinfo(1).source:match("@?(.*[\\|/])") .. "classic.lua")

--#region GUtil

GUtil = {}

function GUtil.IsNilOrEmpty(s) return s == nil or s == "" end

function GUtil.IsNumber(s)
    assert(type(s) == "string")
    return tonumber(s) ~= nil
end

function GUtil.IsInt(s)
    assert(type(s) == "string")
    return tonumber(s, 10) ~= nil
end

function GUtil.IsBool(s)
    assert(type(s) == "string")
    return string.lower(s) == "true" or string.lower(s) == "false"
end

function GUtil.ToBool(s)
    assert(type(s) == "string")
    if string.lower(s) == "true" then
        return true
    elseif string.lower(s) == "false" then
        return false
    else
        return nil
    end
end

function GUtil.OpenURL(url)
    local command <const> = reaper.IsMacOS() and 'open "" "' .. url .. '"' or 'start "" "' .. url .. '"'
    os.execute(command)
end

--#endregion

--#region Config

Config = Object:extend()

function Config:new(category)
    self.cfgName = "GUtilities"
    self.category = category
end

function Config:Read(key)
    local success <const>, value <const> = reaper.GU_Config_Read(self.cfgName, self.category, tostring(key))

    if not success then return nil end

    if GUtil.IsNumber(value) then
        return tonumber(value)
    elseif GUtil.IsBool(value) then
        return GUtil.ToBool(value)
    else
        return value
    end
end

function Config:Write(key, value)
    if GUtil.IsNilOrEmpty(key) or GUtil.IsNilOrEmpty(value) then return end

    local success <const> = reaper.GU_Config_Write(self.cfgName, self.category, tostring(key), tostring(value))

    if not success then reaper.log("GU_Config_Write failed!\n") end
end

--#endregion Config

--#region CheckDependencies

local dependencyInfo <const> = {
    { Name = "SWS",             Func = "CF_GetSWSVersion",        Web = "https://www.sws-extension.org" },
    { Name = "ReaImGui",        Func = "ImGui_GetVersion",        Web = "https://forum.cockos.com/showthread.php?t=250419" },
    { Name = "js_ReaScriptAPI", Func = "JS_ReaScriptAPI_Version", Web = "https://forum.cockos.com/showthread.php?t=212174" },
}

function CheckGUtilitiesAPIDependency()
    if not reaper.APIExists("GU_GUtilitiesAPI_GetVersion") then
        error(
            "GUtilitiesAPI is not installed. Please use ReaPack's Browse Packages feature and ensure that it is installed. " ..
            "If you have installed it during this session, you will need to restart Reaper before it can be loaded.")
    end
end

function CheckDependencies()
    local mbMsg <const> = " is not installed.\n\nWould you like to be redirected now?"
    local errorMsg <const> = " is not installed.\n\nPlease ensure it is installed before using this script"

    CheckGUtilitiesAPIDependency()
    for _, info in pairs(dependencyInfo) do
        if not reaper.APIExists(info.Func) then
            if reaper.MB(info.Name .. mbMsg, "Error", MessageBoxType.OKCANCEL) == MessageBoxReturn.OK then
                GUtil.OpenURL(info.Web)
            end
            error(info.Name .. errorMsg)
        end
    end
end

CheckDependencies()

--#endregion CheckDependencies

--#region Debug

_Debug = Object:extend()

function _Debug:new()
    self.config = Config("debug")
    self.isEnabled = self.config:Read("enabled")
end

function _Debug:Log(s, ...)
    if not self.isEnabled then return end

    reaper.ShowConsoleMsg(string.format(s, ...))
end

Debug = _Debug() -- define object globally

--#endregion

--#region Maths

Maths = {}

function Maths.Erf(x)
    -- https://hewgill.com/picomath/lua/erf.lua.html

    -- constants
    local a1 <const> = 0.254829592
    local a2 <const> = -0.284496736
    local a3 <const> = 1.421413741
    local a4 <const> = -1.453152027
    local a5 <const> = 1.061405429
    local p <const> = 0.3275911

    -- Save the sign of x
    local sign = 1
    if x < 0 then
        sign = -1
    end
    x = math.abs(x)

    -- A&S formula 7.1.26
    local t <const> = 1.0 / (1.0 + p * x)
    local y <const> = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x)

    return sign * y
end

function Maths.Clamp(value, min_range, max_range)
    return math.min(math.max(value, min_range), max_range)
end

function Maths.EaseOutBounce(x)
    local n1 <const> = 7.5625
    local d1 <const> = 2.75

    if x < 1 / d1 then
        return n1 * x * x
    elseif x < 2 / d1 then
        local y <const> = x - 1.5 / d1
        return n1 * y * y + 0.75
    elseif x < 2.5 / d1 then
        local y <const> = x - 2.25 / d1
        return n1 * y * y + 0.9375
    else
        local y <const> = x - 2.625 / d1
        return n1 * y * y + 0.984375
    end
end

function Maths.EaseInOutCubic(x)
    if x < 0.5 then
        return 4 * x * x * x
    else
        return 1 - (-2 * x + 2) ^ 3 / 2
    end
end

function Maths.DB2VOL(dB) return 10.0 ^ (0.05 * dB) end

function Maths.VOL2DB(vol) return 20.0 * math.log(vol, 10) end

function Maths.IsNearlyEqual(x, y, eps)
    eps = eps or 0.00001
    return math.abs(x - y) < eps;
end

function Maths.Round(input, precision)
    --https://ardoris.wordpress.com/2008/11/07/rounding-to-a-certain-number-of-decimal-places-in-lua/
    local x <const> = 10 ^ precision
    return math.floor(input * x + 0.5) / x
end

Int32 = {
    min = -0x80000000,
    max = 0x7FFFFFFF
}

--#endregion Maths

--#region FileSystem

FileSys = {}

FileSys.ValidFileFormats = {
    ".WAV", ".AIFF", ".FLAC", ".MP3", ".OGG",
    ".BWF", ".W64", ".WAVPACK", ".GIF", "MP4"
}

-- extList example "ReaScript files\0*.lua;*.eel\0Lua files (.lua)\0*.lua\0EEL files (.eel)\0*.eel\0\0"
function FileSys.SaveDialog(title, path, fileName, extList)
    local rv <const>, path <const> = reaper.JS_Dialog_BrowseForSaveFile(title,
        GUtil.IsNilOrEmpty(path) and FileSys.Path.Default() or path, fileName, extList)

    if rv == -1 then
        error("JS_Dialog_BrowseForSaveFile returned an error")
    elseif rv == 0 then
        Debug:Log("JS_Dialog_BrowseForSaveFile was cancelled by user")
        return ""
    else
        return path
    end
end

function FileSys.FolderDialog(defaultPath, tooltip)
    local rv <const>, path <const> = reaper.JS_Dialog_BrowseForFolder(tooltip,
        GUtil.IsNilOrEmpty(defaultPath) and FileSys.Path.Default() or defaultPath)

    if rv == -1 then    -- error
        error("BrowseForFolder returned an error")
    elseif rv == 0 then -- user cancelled
        return nil
    else
        return path -- success
    end
end

function FileSys.GetRawName(fileName)
    return fileName:sub(1, #fileName - 4)
end

FileSys.Path = {}

-- Returns the Directory, File Name, and Extension as 3 values
function FileSys.Path.Parse(path)
    if reaper.IsWinOs() then
        return path:match("(.-)([^\\]-([^\\%.]+))$")
    else
        return path:match("(.-)([^/]-([^/]+))$")
    end
end

-- Splits directory into table for each token
function FileSys.Path.Split(path)
    if not FileSys.Path.Exists(path) then error(string.format("%s is not a valid path", path)) end

    local tokens <const> = reaper.IsWinOs() and path:gmatch("[^\\]+") or path:gmatch("[^/]+")
    local result <const> = {}

    for token in tokens do
        table.insert(result, token)
    end

    if string.find(result[#result], "%.") then -- if has file extension
        table.remove(result)
    end

    return result
end

function FileSys.Path.Default() return reaper.IsWinOs() and "C:/" or "/" end

function FileSys.Path.Exists(path) return reaper.GU_Filesystem_PathExists(path) end

function FileSys.Path.Difference(pathTable1, pathTable2)
    local result <const> = {}

    for key, val in pairs(pathTable2) do
        if pathTable1[key] ~= val then
            result[key] = val
        end
    end

    return result
end

--#endregion Filesystem

--#region Color

Col = {}

Col.White = 0xffffffff
Col.Red = 0xff0000ff

function Col.CreateRGBA(red, gre, blu, alp)
    local alphaMax <const> = 255
    alp = alp or alphaMax
    return ((red & 0xff) << 24) | ((gre & 0xff) << 16) | ((blu & 0xff) << 8) | (alp & 0xff)
end

function Col.GetColorTable(rgba)
    if not rgba then return { red = nil, green = nil, blue = nil, alpha = nil } end
    local red <const> = (rgba >> 24) & 0xff
    local green <const> = (rgba >> 16) & 0xff
    local blue <const> = (rgba >> 8) & 0xff
    local alpha <const> = rgba & 0xff

    return { red = red, green = green, blue = blue, alpha = alpha }
end

--#endregion

--#region Table

function table.clear(t)
    for key, _ in pairs(t) do
        t[key] = nil
    end
end

function table.contains(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

function table.isEmpty(t)
    return next(t) == nil
end

--#endregion

--#region File

File = Object:extend()

File.Mode = { Read = "r", Write = "w" }

function File:new(path, mode)
    path = path or FileSys.Path.Default()
    mode = mode or File.Mode.Read
    self.isOpen = false
    local file <const>, err <const> = io.open(path, mode)
    if file == nil then
        error("file creation failed\nerr: " .. err)
    end
    self.file = file
    self.isOpen = true
end

function File:Write(s) self.file:write(s) end

function File:__close() if self.isOpen then return self.file:close() end end

--#endregion File

--#region FileTypes

MediaFlag = {
    RESET = -1,
    ALL = 0,
    WAV = 1 << 0,
    AIFF = 1 << 1,
    FLAC = 1 << 2,
    MP3 = 1 << 3,
    OGG = 1 << 4,
    BWF = 1 << 5,
    W64 = 1 << 6,
    WAVPACK = 1 << 7,
    GIF = 1 << 8,
    MP4 = 1 << 9,
}

--#endregion
