-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('Lua.gutil_classic')

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
---@field color integer
---@field startPos number # in seconds

---@class (exact) RegionInfo : MarkerInfo
---@field endPos number # in seconds

---@return MarkerInfo[], RegionInfo[]
function Project:GetMarkersAndRegions()
    local markers <const> = {} ---@type MarkerInfo[]
    local regions <const> = {} ---@type RegionInfo[]
    for i = 0, reaper.CountProjectMarkers(self.id) - 1 do
        local _, isRegion <const>, _startPos <const>, _endPos <const>, _name <const>, _index <const>, _color <const> =
            reaper.EnumProjectMarkers3(self.id, i)

        if not isRegion then
            local marker <const> = { index = _index, name = _name, startPos = _startPos, endPos = _endPos, color = _color } ---@type MarkerInfo
            table.insert(markers, marker)
        else
            local region <const> = { index = _index, name = _name, startPos = _startPos, endPos = _endPos, color = _color } ---@type RegionInfo
            table.insert(regions, region)
        end
    end

    return markers, regions
end

---@param index integer
---@param pos number
---@param name string
---@param color integer
---@return boolean # whether set was successful or not
function Project:SetMarker(index, pos, name, color)
    local flag <const> = Str.IsBlank(name) and 1 or 0
    return reaper.SetProjectMarker4(self.id, index, false, pos, 0, name, color, flag)
end

---@param index integer
---@param startPos number
---@param endPos number
---@param name string
---@param color integer
---@return boolean # whether set was successful or not
function Project:SetRegion(index, startPos, endPos, name, color)
    local flag <const> = Str.IsBlank(name) and 1 or 0
    return reaper.SetProjectMarker4(self.id, index, true, startPos, endPos, name, color, flag)
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
    local specialRegions = {} ---@type RegionInfo[]
    local regionList --[[@type RegionInfo[] ]] <const> = select(2, self:GetMarkersAndRegions())
    for _, region in pairs(regionList) do
        if region.name:find("=") then
            table.insert(specialRegions, region)
        end
    end
    return specialRegions
end

---@nodiscard
function Project:GetSpecialMarkers()
    local specialMarkers = {} ---@type MarkerInfo[]
    local markerList --[[@type MarkerInfo[] ]] <const> = select(1, self:GetMarkersAndRegions())
    for _, marker in pairs(markerList) do
        if marker.name:find("=") then
            table.insert(specialMarkers, marker)
        end
    end
    return specialMarkers
end

---@param pos number
---@param name? string
---@param color? integer
function Project:InsertMarker(pos, name, color)
    name = name or ""
    color = color or 0
    reaper.AddProjectMarker2( self.id, false, pos, 0, name, 0, color)
end

---@param posStart number
---@param posEnd number
---@param name? string
---@param color? integer
function Project:InsertRegion(posStart, posEnd, name, color)
    name = name or ""
    color = color or 0
    reaper.AddProjectMarker2( self.id, true, posStart, posEnd, name, 0, color)
end

function Project:GetCursorPos()
    return reaper.GetCursorPositionEx(self.id)
end

---@param time number
function Project:SetCursorPos(time)
    reaper.SetEditCurPos2( self.id, time, false, false )
end

function Project:SelectAllItems() reaper.SelectAllMediaItems(THIS_PROJECT, true) end

return Project