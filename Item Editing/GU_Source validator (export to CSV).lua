-- @description Source validator (export to CSV)
-- @author guonaudio
-- @version 1.4
-- @changelog
--   Update path to work in Linux
-- @about
--   Collates information about source audio within the project.
--   This tool skips loading the GUI, and instead exports directly to CSV.

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../Lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Full.sourcevalidator')

local gui <const> = GuiSrcValidator("GU_Source validator.lua", "NA", false)

reaper.defer(function () gui:Loop() end)
