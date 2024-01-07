-- @description Item alias generator
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Generates empty items in parent track based on all overlapping items in child tracks

local scriptPath = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")

local ItemAliasGen <const> = Action:extend()

function ItemAliasGen:new(undoText)
    self.undoText = undoText
    self.primoTracks = {} -- map where key = MediaTrack, and value = table of item start/end time pairs
end

function ItemAliasGen:AddToPrimoTracks(ptr, item)
    self.primoTracks[ptr] = self.primoTracks[ptr] or {} -- if doesn't exist, create new
    table.insert(self.primoTracks[ptr], { item:GetStart(), item:GetEnd() })
end

function ItemAliasGen:FillData()
    local items = Items(FillType.Selected)

    for _, item in pairs(items.array) do
        local trackPtr = item:GetTrackPtr()
        assert(trackPtr, "MediaItem must exist on a MediaTrack")

        local track = Track(trackPtr)

        if not track:IsRoot() then -- only process items on child tracks
            self:AddToPrimoTracks(track:GetPrimogenitorPtr(), item)
        end
    end
end

function ItemAliasGen:MergeOverlapping(data)
    table.sort(data, function (a, b) return a[1] < b[1] end)

    local merged = {}
    local interval = data[1]
    for i = 2, #data do
        local newInterval = data[i]

        if newInterval[1] <= interval[2] then
            interval[2] = math.max(interval[2], newInterval[2])
        else
            table.insert(merged, interval)
            interval = newInterval
        end
    end

    table.insert(merged, interval) -- bookend final interval

    return merged
end

function ItemAliasGen:ConsolidateData()
    for ptr, data in pairs(self.primoTracks) do
        self.primoTracks[ptr] = self:MergeOverlapping(data)
    end
end

function ItemAliasGen:CreateBlankItems()
    for ptr, data in pairs(self.primoTracks) do
        assert(ptr, "MediaTrack should still be valid")

        local track = Track(ptr)
        for _, itemInfo in ipairs(data) do
            track:CreateBlankItem("", itemInfo[1], itemInfo[2] - itemInfo[1])
        end
    end
end

function ItemAliasGen:Process()
    self:Begin()

    self:FillData()
    self:ConsolidateData()
    self:CreateBlankItems()

    self:Complete(reaper.UndoState.Items)
end

ItemAliasGen("Generate item aliases"):Process()
