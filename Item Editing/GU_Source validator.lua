-- @description Source Validator
-- @author guonaudio
-- @version 1.2
-- @changelog
--   Match require case to path case for Unix systems
-- @about
--   Displays collated information about source audio within the project.
--   This tool can also flag files which don't meet user customisable standards.

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Full.sourcevalidator')

local gui <const> = GuiSrcValidator("GU_Source validator.lua", "NA", true)

reaper.defer(function () gui:Loop() end)
