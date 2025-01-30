-- @description Item alias generator
-- @author guonaudio
-- @version 2.0
-- @changelog
--   Sets name, color, and snap offset for generated item alias from first overlapping Item.
--   Also adds Take Markers from all overlapping Items 
-- @about
--   Generates empty items in topmost parent track based on all overlapping items in child tracks

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_table')
require('Reaper.gutil_action')
require('Reaper.gutil_item')
require('Reaper.gutil_project')
require('Reaper.gutil_take')
require('Reaper.gutil_track')

---@class (exact) ItemAlias
---@field startPos number
---@field endPos number
---@field name string
---@field col integer
---@field snapOffset number
---@field markers TakeMarkerInfo[]

---@class ItemAliasGen : Object, Action
---@operator call: ItemAliasGen
ItemAliasGen = Object:extend()
ItemAliasGen:implement(Action)

---@param undoText string
function ItemAliasGen:new(undoText)
    self.undoText = undoText
    self.primoTracks = {} ---@type { [MediaTrack] : ItemAlias[] }
end

---@param track Track
---@param item Item
function ItemAliasGen:AddToPrimoTracks(track, item)
    self.primoTracks[track.id] = self.primoTracks[track.id] or {} -- if doesn't exist, create new
    local itemAlias --[[@type ItemAlias]] = {
        startPos = item:GetStart(),
        endPos = item:GetEnd(),
        name = item:GetActiveTake():GetString("P_NAME"),
        col = toint(item:GetValue("I_CUSTOMCOLOR")),
        snapOffset = item:GetValue("D_SNAPOFFSET"),
        markers = item:GetActiveTake():GetMarkers()
    }

    table.insert(self.primoTracks[track.id], itemAlias)
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

---@param itemAliases ItemAlias[]
function ItemAliasGen:MergeOverlapping(itemAliases)
    table.sort(itemAliases, function (A, B) return A.startPos < B.startPos end) -- sort TimePairs by start

    local mergedAliases <const> = {} ---@type ItemAlias[]
    local curAlias = itemAliases[1] ---@type ItemAlias # Assign interval to first pair
    for i = 2, #itemAliases do
        local latestAlias <const> = itemAliases[i]

        if latestAlias.startPos <= curAlias.endPos then -- grow first
            do -- add take markers to current
                local overlapDuration <const> = curAlias.endPos - latestAlias.startPos
                local posOffset <const> = curAlias.endPos - curAlias.startPos - overlapDuration
                for _, marker in pairs(latestAlias.markers) do
                    table.insert(curAlias.markers, marker)
                    curAlias.markers[#curAlias.markers].pos = posOffset + curAlias.markers[#curAlias.markers].pos
                end
            end
            curAlias.endPos = math.max(curAlias.endPos, latestAlias.endPos)
        else -- insert finished and start new
            table.insert(mergedAliases, curAlias)
            curAlias = latestAlias
        end
    end

    table.insert(mergedAliases, curAlias) -- bookend final interval

    return mergedAliases
end

function ItemAliasGen:ConsolidateData()
    for trackId, itemAliases in pairs(self.primoTracks) do
        self.primoTracks[trackId] = self:MergeOverlapping(itemAliases)
    end
end

function ItemAliasGen:CreateBlankItems()
    for trackId, itemAliases in pairs(self.primoTracks) do
        for _, itemAlias in pairs(itemAliases) do
            local track <const> = Track(trackId)
            local item = track:CreateBlankItem("", itemAlias.startPos, itemAlias.endPos - itemAlias.startPos)
            item:GetActiveTake():SetString("P_NAME", itemAlias.name)
            item:SetValue("I_CUSTOMCOLOR", itemAlias.col)
            item:SetValue("D_SNAPOFFSET", itemAlias.snapOffset)
            for _, marker in pairs(itemAlias.markers) do
                item:GetActiveTake():AddMarker(marker)
            end
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
