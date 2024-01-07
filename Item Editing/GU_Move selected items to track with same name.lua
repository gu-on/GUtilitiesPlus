-- @description Move selected items to track with same name
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Move items to first found track with the same name

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")

ItemToTrackMover = Action:extend()

function ItemToTrackMover:new(undoText)
    self.undoText = undoText
end

function ItemToTrackMover:MoveItems()
    local items <const> = Items(FillType.Selected)
    local tracks <const> = Tracks(FillType.All)

    for _, item in pairs(items.array) do
        local takePtr <const> = item:GetActiveTakePtr()
        if takePtr == nil then goto continue end

        local take <const> = Take(takePtr)
        for _, track in pairs(tracks.array) do
            if string.find(tostring(track), tostring(take)) ~= nil then
                item:SetTrack(track.ptr)
            end
        end

        ::continue::
    end
end

function ItemToTrackMover:Process()
    self:Begin()
    self:MoveItems()
    self:Complete(reaper.UndoState.Items)
end

ItemToTrackMover("Move items to track of same name"):Process()
