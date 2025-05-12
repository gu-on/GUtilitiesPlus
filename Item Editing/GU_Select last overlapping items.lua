-- @description Select last overlapping items
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Selects last Item for any given set of overlapping Items, per track 

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_table')
require('Reaper.gutil_item')
require('Reaper.gutil_project')
require('Reaper.gutil_track')

local project <const> = Project(THIS_PROJECT)
local items <const> = project:GetSelectedItems()
local runningItems = {} ---@type Item[]
local finalItems = {} ---@type Item[]

for index, item in ipairs(items) do
    if table.isEmpty(runningItems) then
        table.insert(runningItems, item)
        goto continue
    end

    if index == #items then -- finish off if last item
        table.insert(finalItems, item)
        goto continue
    end

    if item:GetTrack() == runningItems[#runningItems]:GetTrack() and item:GetStart() < runningItems[#runningItems]:GetEnd() then
        table.insert(runningItems, item)
        goto continue
    end

    table.insert(finalItems, runningItems[#runningItems])
    runningItems = {}
    table.insert(runningItems, item)

    ::continue::
end

project:DeselectAllItems()

for _, item in pairs(finalItems) do
    item:SetSelected(true)
end

project:Refresh()
