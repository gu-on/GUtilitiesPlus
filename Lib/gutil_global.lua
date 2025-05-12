-- @description GUtilities libraries (essential)
-- @author guonaudio
-- @version 2.3
-- @provides 
--   [nomain] .
--   [nomain] Lua/gutil_classic.lua
--   [nomain] Lua/gutil_color.lua
--   [nomain] Lua/gutil_curve.lua
--   [nomain] Lua/gutil_filesystem.lua
--   [nomain] Lua/gutil_maths.lua
--   [nomain] Lua/gutil_string.lua
--   [nomain] Lua/gutil_table.lua
--   [nomain] Reaper/gutil_action.lua
--   [nomain] Reaper/gutil_config.lua
--   [nomain] Reaper/gutil_fx.lua
--   [nomain] Reaper/gutil_gui.lua
--   [nomain] Reaper/gutil_item.lua
--   [nomain] Reaper/gutil_midi.lua
--   [nomain] Reaper/gutil_progressbar.lua
--   [nomain] Reaper/gutil_project.lua
--   [nomain] Reaper/gutil_source.lua
--   [nomain] Reaper/gutil_take.lua
--   [nomain] Reaper/gutil_track.lua
--   [nomain] Full/sourcevalidator.lua
-- @changelog
--   Remove os, cmd, and dependency libs (refactored into global)
--   Added in new libs for fx and midi
-- @about
--   Main library for handling all other required libraries

---@alias OperatingSystems
---| "Win32" # Win32
---| "Win64" # Win64
---| "OSX32" # OSX32
---| "OSX64" # OSX64
---| "macOSarm64" # macOS-arm64
---| "other" # Other

---@class Os
Os = {}

function Os.IsWin()
    local os <const> = reaper.GetOS() ---@type OperatingSystems
    return
        os == "Win32" or
        os == "Win64"
end

function Os.IsMac()
    local os <const> = reaper.GetOS() ---@type OperatingSystems
    return
        os == "OSX32" or 
        os == "OSX64" or 
        os == "macOSarm64"
end

function reaper.IsLinuxOS()
    return not Os.IsWin() and not Os.IsMac() -- may change in future?
end

---@class Cmd
Cmd = {}

---@param url string
function Cmd.OpenURL(url)
    local command <const> = Os.IsMac() and 'open "" "' .. url .. '"' or 'start "" "' .. url .. '"'
    os.execute(command)
end

---@alias MessageBoxType
---| 0 # OK
---| 1 # OKCANCEL
---| 2 # ABORTRETRYIGNORE
---| 3 # YESNOCANCEL
---| 4 # YESNO
---| 5 # RETRYCANCEL

---@alias MessageBoxReturn
---| 1 # OK
---| 2 # CANCEL
---| 3 # ABORT
---| 4 # RETRY
---| 5 # IGNORE
---| 6 # YES
---| 7 # NO

---@class Dialog
Dialog = {}

---comment
---@param msg string
---@param title string
---@param mbtype MessageBoxType
---@return MessageBoxReturn
function Dialog.MB(msg, title, mbtype)
    return reaper.MB(msg, title, mbtype)
end

---@class Debug
Debug = {
    enabled = false
}

---@param str string
---@param ... unknown
function Debug.Log(str, ...)
    if not Debug.enabled then return end
    reaper.ShowConsoleMsg(string.format(str, ...)) -- simple always on logging
end

do -- Check dependencies
    DependencyInfo = {
        { Name = "SWS",             Func = "CF_GetSWSVersion",        Web = "https://www.sws-extension.org" },
        { Name = "ReaImGui",        Func = "ImGui_GetVersion",        Web = "https://forum.cockos.com/showthread.php?t=250419" },
        { Name = "js_ReaScriptAPI", Func = "JS_ReaScriptAPI_Version", Web = "https://forum.cockos.com/showthread.php?t=212174" },
    }

    local mbMsg <const> = " is not installed.\n\nWould you like to be redirected now?"
    local errorMsg <const> = " is not installed.\n\nPlease ensure it is installed before using this script"

    if not reaper.APIExists("GU_GUtilitiesAPI_GetVersion") then
        error(
            "GUtilitiesAPI is not installed. Please use ReaPack's Browse Packages feature and ensure that it is installed. " ..
            "If you have installed it during this session, you will need to restart Reaper before it can be loaded.")
    end
    for _, info in pairs(DependencyInfo) do
        if not reaper.APIExists(info.Func) then
            local input <const> = Dialog.MB(info.Name .. mbMsg, "Error", 1)
            if input == 1 then
                Cmd.OpenURL(info.Web)
            end
            error(info.Name .. errorMsg)
        end
    end
end

reaper.AudioFormats = { "WAV", "AIFF", "FLAC", "MP3", "OGG", "BWF", "W64", "WAVPACK" }

---@param e string|number
---@return integer
---@diagnostic disable-next-line: lowercase-global
function toint(e) return math.floor(e and tonumber(e) or 0) end

---@alias CommandID
---| 40245 # Peaks: Build any missing peaks for selected items

---@alias UndoState
---| -1 # All = -1,
---| 1 # TrackCFG = 1 << 0,   -- track/master vol/pan/routing, routing/hwout envelopes too
---| 2 # FX = 1 << 1,         -- track/master fx
---| 4 # Items = 1 << 2,      -- track items
---| 8 # MiscCFG = 1 << 3,    -- loop selection, markers, regions, extensions
---| 16 # Freeze = 1 << 4,     -- freeze state
---| 32 # TrackENV = 1 << 5,   -- non-FX envelopes only
---| 64 # FxENV = 1 << 6,      -- FX envelopes, implied by UNDO_STATE_FX too
---| 128 # PooledENVS = 1 << 7, -- contents of automation items -- not position, length, rate etc of automation items, which is part of envelope state
---| 256 # ARA = 1 << 8         -- ARA state

---@alias FadeDirection
---| 0 # In
---| 1 # Out

---@alias FadeShapeIndex
---| 0 # linear
---| 1 # fastStart
---| 2 # fastEnd
---| 3 # fastStartSteep
---| 4 # fastEndSteep
---| 5 # slowStartEnd
---| 6 # slowStartEndSteep

---@alias FadeShapeName
---| '"linear"' # 0
---| '"fastStart"' # 1
---| '"fastEnd"' # 2
---| '"fastStartSteep"' # 3
---| '"fastEndSteep"' # 4
---| '"slowStartEnd"' # 5
---| '"slowStartEndSteep"' # 6

---@alias NormalizationType
---| 0 # LUFS_I
---| 1 # RMS
---| 2 # PEAK
---| 3 # TRUE_PEAK
---| 4 # LUFS_M
---| 5 # LUFS_S

---@alias MediaFlag
---| -1 # RESET
---| 0 # ALL
---| 1 # WAV 1 << 0
---| 2 # AIFF 1 << 1
---| 4 # FLAC 1 << 2
---| 8 # MP3 1 << 3
---| 16 # OGG 1 << 4
---| 32 # BWF 1 << 5
---| 64 # W64 1 << 6
---| 128 # WAVPACK 1 << 7
---| 256 # GIF 1 << 8
---| 512 # MP4 1 << 9