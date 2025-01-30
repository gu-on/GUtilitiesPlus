-- @description Move selected items to track with same name
-- @author guonaudio
-- @version 1.2
-- @changelog
--   Match require case to path case for Unix systems
-- @about
--   Move items to first found track with the same name

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_classic')
require('Reaper.gutil_action')
require('Reaper.gutil_item')
require('Reaper.gutil_project')
require('Reaper.gutil_take')
require('Reaper.gutil_track')

---@class ItemToTrackMover : Action
---@operator call : ItemToTrackMover
ItemToTrackMover = Action:extend()

function ItemToTrackMover:new(undoText)
    self.undoText = undoText
end

function ItemToTrackMover:MoveItems()
    local project <const> = Project(THIS_PROJECT)
    local items <const> = project:GetSelectedItems()
    local tracks <const> = project:GetAllTracks()

    for _, item in pairs(items) do
        local take <const> = item:GetActiveTake()
        if take == nil then goto continue end

        for _, track in pairs(tracks) do
            if string.find(track:GetString("P_NAME"), take:GetString("P_NAME")) ~= nil then
                item:SetTrack(track)
            end
        end

        ::continue::
    end
end

function ItemToTrackMover:Process()
    self:Begin()
    self:MoveItems()
    self:Complete(4)
end

ItemToTrackMover("Move items to track of same name"):Process()
