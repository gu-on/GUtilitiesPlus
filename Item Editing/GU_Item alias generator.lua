-- @description Item alias generator
-- @author guonaudio
-- @version 1.1
-- @changelog
--   Refactor to make better use of Lua Language Server
-- @about
--   Generates empty items in parent track based on all overlapping items in child tracks

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('lua.gutil_classic')
require('lua.gutil_table')
require('reaper.gutil_action')
require('reaper.gutil_item')
require('reaper.gutil_project')
require('reaper.gutil_take')
require('reaper.gutil_track')

---@class (exact) TimePair
---@field Start number
---@field End number

---@class ItemAliasGen : Object, Action
---@operator call: ItemAliasGen
ItemAliasGen = Object:extend()
ItemAliasGen:implement(Action)

---@param undoText string
function ItemAliasGen:new(undoText)
    self.undoText = undoText
    self.primoTracks = {} ---@type {[MediaTrack]: TimePair}
end

---@param track Track
---@param item Item
function ItemAliasGen:AddToPrimoTracks(track, item)
    self.primoTracks[track.id] = self.primoTracks[track.id] or {} -- if doesn't exist, create new
    table.insert(self.primoTracks[track.id], { Start = item:GetStart(), End = item:GetEnd(), fluven = 10 })
end

function ItemAliasGen:FillData()
    local items <const> = Project(THIS_PROJECT):GetSelectedItems()
    for _, item in pairs(items) do
        local track <const> = item:GetTrack()
        if track:GetDepth() ~= 0 then -- only process items on child tracks
            self:AddToPrimoTracks(track:GetPrimogenitor(), item)
        end
    end
end

---@param timePairs TimePair[]
function ItemAliasGen:MergeOverlapping(timePairs)
    table.sort(timePairs, function (A, B) return A.Start < B.Start end) -- sort TimePairs by start

    local mergedTimes <const> = {} ---@type TimePair[]
    local interval = timePairs[1] ---@type TimePair # Assign interval to first pair
    for i = 2, #timePairs do
        local newInterval <const> = timePairs[i]

        if newInterval.Start <= interval.End then
            interval.End = math.max(interval.End, newInterval.End)
        else
            table.insert(mergedTimes, interval)
            interval = newInterval
        end
    end

    table.insert(mergedTimes, interval) -- bookend final interval

    return mergedTimes
end

function ItemAliasGen:ConsolidateData()
    for trackId, timePairs in pairs(self.primoTracks) do
        self.primoTracks[trackId] = self:MergeOverlapping(timePairs)
    end
end

function ItemAliasGen:CreateBlankItems()
    for trackId, timePairs in pairs(self.primoTracks) do
        for _, timePair in pairs(timePairs) do
            local track <const> = Track(trackId)
            track:CreateBlankItem("", timePair.Start, timePair.End - timePair.Start)
        end
    end
end

function ItemAliasGen:Process()
    self:Begin()

    self:FillData()
    self:ConsolidateData()
    self:CreateBlankItems()

    self:Complete(4)
end

local main <const> = ItemAliasGen("Generate item aliases")

main:Process()