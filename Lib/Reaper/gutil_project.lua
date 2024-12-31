-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('lua.gutil_classic')

THIS_PROJECT = 0

---@class Project : Object
---@operator call: Project
Project = Object:extend()

---@param id 0|ReaProject|nil
function Project:new(id)
    self.id = id or THIS_PROJECT
end

function Project:CountSelectedItems() return reaper.CountSelectedMediaItems(self.id) end

---Creates a new track at the specified index in the project's hierarchy
---@param index integer 
---@param name string
function Project:CreateNewTrack(index, name)
    local wantDefaults <const> = false
    reaper.InsertTrackAtIndex(index, wantDefaults)
    local track <const> = Track(reaper.GetTrack(THIS_PROJECT, index)) ---@type Track
    track:SetString("P_NAME", name)
    return track
end

function Project:DeselectAllItems() reaper.SelectAllMediaItems(THIS_PROJECT, false) end

---@return Item[]
---@nodiscard
function Project:GetAllItems()
    local items <const> = {} ---@type Item[]
    for i = 0, reaper.CountMediaItems(self.id) - 1 do
        table.insert(items, Item(reaper.GetMediaItem(self.id, i)))
    end
    return items
end

---@return Track[]
---@nodiscard
function Project:GetAllTracks()
    local tracks <const> = {} ---@type Track[]
    for i = 0, reaper.CountTracks(self.id) - 1 do
        table.insert(tracks, Track(reaper.GetTrack(self.id, i)))
    end
    return tracks
end

--@nodiscard
function Project:GetName() return reaper.GetProjectName(self.id) end

---@class (exact) MarkerInfo
---@field index integer
---@field name string
---@field startPos number # in seconds

---@class (exact) RegionInfo : MarkerInfo
---@field endPos number # in seconds

---@return MarkerInfo[], RegionInfo
function Project:GetRegionsAndMarkers()
    local markers <const> = {} ---@type MarkerInfo[]
    local regions <const> = {} ---@type RegionInfo[]
    for i = 0, reaper.CountProjectMarkers(self.id) - 1 do
        local _, isRegion <const>, _startPos <const>, _endPos <const>, _name <const>, _index <const> =
            reaper.EnumProjectMarkers(i)

        if not isRegion then
            local marker <const> = { index = _index, name = _name, startPos = _startPos, endPos = _endPos } ---@type MarkerInfo
            table.insert(markers, marker)
        else
            local region <const> = { index = _index, name = _name, startPos = _startPos, endPos = _endPos } ---@type RegionInfo
            table.insert(regions, region)
        end
    end

    return markers, regions
end

---@return Item[]
---@nodiscard
function Project:GetSelectedItems()
    local items <const> = {} ---@type Item[]
    for i = 0, reaper.CountSelectedMediaItems(self.id) - 1 do
        table.insert(items, Item(reaper.GetSelectedMediaItem(self.id, i)))
    end
    return items
end

---@return Track[]
---@nodiscard
function Project:GetSelectedTracks()
    local tracks <const> = {} ---@type Track[]
    for i = 0, reaper.CountSelectedTracks(self.id) - 1 do
        table.insert(tracks, Track(reaper.GetSelectedTrack(self.id, i)))
    end
    return tracks
end

---@nodiscard
function Project:GetSpecialRegions()
    local specialRegions <const> = {}
    local _, regionList = self:GetRegionsAndMarkers()
    for _, region in pairs(regionList) do
        if string.find(region.name, "=") then
            table.insert(specialRegions, region)
        end
    end
    return specialRegions
end


function Project:SelectAllItems() reaper.SelectAllMediaItems(THIS_PROJECT, true) end

return Project