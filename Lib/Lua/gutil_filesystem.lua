-- @noindex

---@class FileSys
FileSys = {}

-- FileSys.ValidFileFormats = {
--     ".WAV", ".AIFF", ".FLAC", ".MP3", ".OGG",
--     ".BWF", ".W64", ".WAVPACK", ".GIF", "MP4"
-- }

---extList example "ReaScript files\0*.lua;*.eel\0Lua files (.lua)\0*.lua\0EEL files (.eel)\0*.eel\0\0"
---@param title string
---@param inPath string
---@param fileName string
---@param extList string
---@return string
function FileSys.SaveDialog(title, inPath, fileName, extList)
    local rv <const>, path <const> = reaper.JS_Dialog_BrowseForSaveFile(title,
        Str.IsNilOrEmpty(inPath) and FileSys.Path.Default() or inPath, fileName, extList)

    if rv == -1 then
        error("JS_Dialog_BrowseForSaveFile returned an error")
    elseif rv == 0 then
        Debug.Log("JS_Dialog_BrowseForSaveFile was cancelled by user")
        return ""
    else
        return path
    end
end

---@param defaultPath string?
---@param tooltip string
---@return string?
function FileSys.FolderDialog(defaultPath, tooltip)
    defaultPath = Str.IsNilOrEmpty(defaultPath) and FileSys.Path.Default() or defaultPath ---@cast defaultPath string
    local rv <const>, path <const> = reaper.JS_Dialog_BrowseForFolder(tooltip, defaultPath)

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

---@class Path
FileSys.Path = {}

---@param path string
---@return string directory, string filename, string extension
function FileSys.Path.Parse(path)
    if Os.IsWin() then
        return path:match("(.-)([^\\]-([^\\%.]+))$")
    else
        return path:match("(.-)([^/]-([^/]+))$")
    end
end

---Splits directory into array of strings, one for each token
---@param path string
---@return string[]
function FileSys.Path.Split(path)
    if not FileSys.Path.Exists(path) then error(path:format("%s is not a valid path")) end

    local tokens <const> = Os.IsWin() and path:gmatch("[^\\]+") or path:gmatch("[^/]+")
    local result <const> = {}

    for token in tokens do
        table.insert(result, token)
    end

    if string.find(result[#result], "%.") then -- if has file extension
        table.remove(result)
    end

    return result
end

---@param path string
---@param fileName string
function FileSys.Path.Find(path, fileName)
    return reaper.GU_Filesystem_FindFileInPath(path, fileName)
end

function FileSys.Path.Default() return Os.IsWin() and "C:/" or "/" end

function FileSys.Path.Exists(path) return reaper.GU_Filesystem_PathExists(path) end

---@param pathTable1 string[]
---@param pathTable2 string[]
---@return string[]
function FileSys.Path.Difference(pathTable1, pathTable2)
    local result <const> = {}
    for k, v in pairs(pathTable2) do
        if pathTable1[k] ~= v then
            result[k] = v
        end
    end
    return result
end