-- @description Source validator (export to CSV)
-- @author guonaudio
-- @version 1.1
-- @changelog
--   Refactor to make better use of Lua Language Server
-- @about
--   Collates information about source audio within the project.
--   This tool skips loading the GUI, and instead exports directly to CSV.

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('full.sourcevalidator')
require('lua.gutil_file')
require('reaper.gutil_dialog')

local gui <const> = GuiSrcValidator("GU_Source validator.lua", "NA", false)

reaper.defer(function () gui:Loop() end)
