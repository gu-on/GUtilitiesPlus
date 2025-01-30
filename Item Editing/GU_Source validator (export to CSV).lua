-- @description Source validator (export to CSV)
-- @author guonaudio
-- @version 1.2
-- @changelog
--   Match require case to path case for Unix systems
-- @about
--   Collates information about source audio within the project.
--   This tool skips loading the GUI, and instead exports directly to CSV.

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Full.sourcevalidator')
require('Reaper.gutil_dialog')

local gui <const> = GuiSrcValidator("GU_Source validator.lua", "NA", false)

reaper.defer(function () gui:Loop() end)
