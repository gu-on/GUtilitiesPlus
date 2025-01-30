-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('Lua.gutil_classic')
require('Lua.gutil_maths')

---@alias ItemParamName_Number
---| '"B_MUTE"' # muted (item solo overrides). setting this value will clear C_MUTE_SOLO.
---| '"B_MUTE_ACTUAL"' # muted (ignores solo). setting this value will not affect C_MUTE_SOLO.
---| '"C_LANEPLAYS"' # on fixed lane tracks, 0=this item lane does not play, 1=this item lane plays exclusively, 2=this item lane plays and other lanes also play, -1=this item is on a non-visible, non-playing lane on a formerly fixed-lane track (read-only)
---| '"C_MUTE_SOLO"' # solo override (-1=soloed, 0=no override, 1=unsoloed). note that this API does not automatically unsolo other items when soloing (nor clear the unsolos when clearing the last soloed item), it must be done by the caller via action or via this API.
---| '"B_LOOPSRC"' # loop source
---| '"B_ALLTAKESPLAY"' # all takes play
---| '"B_UISEL"' # selected in arrange view
---| '"C_BEATATTACHMODE"' # item timebase, -1=track or project default, 1=beats (position, length, rate), 2=beats (position only). for auto-stretch timebase: C_BEATATTACHMODE=1, C_AUTOSTRETCH=1
---| '"C_AUTOSTRETCH:"' # auto-stretch at project tempo changes, 1=enabled, requires C_BEATATTACHMODE=1
---| '"C_LOCK"' # locked, &1=locked
---| '"D_VOL"' # item volume, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
---| '"D_POSITION"' # item position in seconds
---| '"D_LENGTH"' # item length in seconds
---| '"D_SNAPOFFSET"' # item snap offset in seconds
---| '"D_FADEINLEN"' # item manual fadein length in seconds
---| '"D_FADEOUTLEN"' # item manual fadeout length in seconds
---| '"D_FADEINDIR"' # item fadein curvature, -1..1
---| '"D_FADEOUTDIR"' # item fadeout curvature, -1..1
---| '"D_FADEINLEN_AUTO"' # item auto-fadein length in seconds, -1=no auto-fadein
---| '"D_FADEOUTLEN_AUTO"' # item auto-fadeout length in seconds, -1=no auto-fadeout
---| '"C_FADEINSHAPE"' #: fadein shape, 0..6, 0=linear
---| '"C_FADEOUTSHAPE"' #: fadeout shape, 0..6, 0=linear
---| '"I_GROUPID"' #: group ID, 0=no group
---| '"I_LASTY"' #: Y-position (relative to top of track) in pixels (read-only)
---| '"I_LASTH"' #: height in pixels (read-only)
---| '"I_CUSTOMCOLOR"' #: custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
---| '"I_CURTAKE"' #: active take number
---| '"IP_ITEMNUMBER"' # item number on this track (read-only, returns the item number directly)
---| '"F_FREEMODE_Y"' # free item positioning or fixed lane Y-position. 0=top of track, 1.0=bottom of track
---| '"F_FREEMODE_H"' # free item positioning or fixed lane height. 0.5=half the track height, 1.0=full track height
---| '"I_FIXEDLANE"' #: fixed lane of item (fine to call with setNewValue, but returned value is read-only)
---| '"B_FIXEDLANE_HIDDEN"' # true if displaying only one fixed lane and this item is in a different lane (read-only)
---| '"P_TRACK"' # (read-only)

---@alias ItemParamName_String
---| '"P_NOTES"' # item note text (do not write to returned pointer, use setNewValue to update)
---| '"P_EXT:"' # extension-specific persistent data
---| '"GUID"' # 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}

---@class Item : Object
---@operator call: Item
Item = Object:extend()

---@param id MediaItem
function Item:new(id)
    self.id = id
    assert(self.id ~= nil, debug.traceback())
end

---@param other Item
function Item:__eq(other) return self.id == other.id end

function Item:__tostring() return tostring(self.id) end

function Item:ClearOffset()
    local snapOffset <const> = self:GetValue("D_SNAPOFFSET")
    if Maths.IsNearlyEqual(snapOffset, 0) then return end

    for _, take in ipairs(self:GetTakes()) do
        local startOffset <const> = take:GetValue("D_STARTOFFS")
        if not take:TryMoveStretchMarkers(snapOffset) then
            take:SetValue("D_STARTOFFS", startOffset + snapOffset)
        end
    end

    self:SetValue("D_POSITION", self:GetValue("D_POSITION") + snapOffset)
    self:SetValue("D_LENGTH", self:GetValue("D_LENGTH") - snapOffset)
    self:SetValue("D_SNAPOFFSET", 0)
    self:UpdateInProject()
end

---@param name string
---@return Take
function Item:CreateBlankTake(name)
    local take <const> = Take(reaper.AddTakeToMediaItem(self.id))
    take:SetString("P_NAME", name)
    return take
end

---@param path string
---@return Take
function Item:CreateNewTake(path)
    local take <const> = Take(reaper.AddTakeToMediaItem(self.id))
    take:SetAudioSource(path)
    take:SetString("P_NAME", select(2, FileSys.Path.Parse(path)))
    return take
end

---@return Take
---@nodiscard
function Item:GetActiveTake()
    return Take(reaper.GetActiveTake(self.id))
end

---@nodiscard
function Item:GetEnd() return reaper.GetMediaItemInfo_Value(self.id, "D_POSITION") + reaper.GetMediaItemInfo_Value(self.id, "D_LENGTH") end

---@nodiscard
function Item:GetStart() return reaper.GetMediaItemInfo_Value(self.id, "D_POSITION") end

---@param param ItemParamName_String
---@nodiscard
function Item:GetString(param) return select(2, reaper.GetSetMediaItemInfo_String(self.id, param, "", false)) end

---@param param ItemParamName_Number
---@nodiscard
function Item:GetValue(param) return reaper.GetMediaItemInfo_Value(self.id, param) end

---@param index integer
function Item:GetTake(index)
    return Take(reaper.GetTake(self.id, index)) ---@type Take
end

---@return Take[]
---@nodiscard
function Item:GetTakes()
    local takes <const> = {} ---@type Take[]
    for i = 0, reaper.CountTakes(self.id) - 1 do
        table.insert(takes, Take(reaper.GetTake(self.id, i)))
    end
    return takes
end

---@return Track
---@nodiscard
function Item:GetTrack()
    return Track(reaper.GetMediaItemTrack(self.id))
end

---@param index integer
function Item:SetActiveTake(index)
    local take <const> = self:GetTake(index)
    if (not take:IsValid()) then return end

    reaper.SetActiveTake(take.id)
end

---@param param ItemParamName_String
---@param value string
function Item:SetString(param, value) reaper.GetSetMediaItemInfo_String(self.id, param, value, true) end

---@param state boolean
function Item:SetSelected(state) reaper.SetMediaItemSelected(self.id, state) end

---@param track Track
function Item:SetTrack(track) reaper.MoveMediaItemToTrack(self.id, track.id) end

---@param param ItemParamName_Number
---@param value number
function Item:SetValue(param, value) reaper.SetMediaItemInfo_Value(self.id, param, value) end

function Item:UpdateInProject() reaper.UpdateItemInProject(self.id) end

return Item