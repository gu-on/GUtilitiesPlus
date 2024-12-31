-- @noindex

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