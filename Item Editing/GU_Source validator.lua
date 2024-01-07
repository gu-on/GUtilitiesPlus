-- @description Source validator
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Displays collated information about source audio within the project.
--   This tool can also flag files which don't meet user customisable standards.

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/gui_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/sourcevalidator_lib.lua")

local gui <const> = GuiSrcValidator("GU_Source validator.lua", "NA", true)

reaper.defer(function() gui:Loop() end)
