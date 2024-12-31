-- @description Source Validator
-- @author guonaudio
-- @version 1.1
-- @changelog
--   Refactor to make better use of Lua Language Server
-- @about
--   Displays collated information about source audio within the project.
--   This tool can also flag files which don't meet user customisable standards.

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('full.sourcevalidator')

local gui <const> = GuiSrcValidator("GU_Source validator.lua", "NA", true)

reaper.defer(function () gui:Loop() end)
