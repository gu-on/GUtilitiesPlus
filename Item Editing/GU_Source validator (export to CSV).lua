-- @description Source validator (export to CSV)
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Collates information about source audio within the project.
--   This tool skips loading the GUI, and instead exports directly to CSV.

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/gui_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/sourcevalidator_lib.lua")

local gui <const> = GuiSrcValidator("GU_Source validator.lua", "NA", false)

reaper.defer(function () gui:Loop() end)
