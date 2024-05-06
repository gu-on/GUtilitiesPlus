-- @version 1.1
-- @noindex

_INCLUDED = _INCLUDED or {}

dofile(debug.getinfo(1).source:match("@?(.*[\\|/])") .. "classic.lua")

function reaper.log(str, ...) reaper.ShowConsoleMsg(string.format(str, ...)) end -- simple always on logging

MessageBoxType = {
    OK = 0,
    OKCANCEL = 1,
    ABORTRETRYIGNORE = 2,
    YESNOCANCEL = 3,
    YESNO = 4,
    RETRYCANCEL = 5
}

MessageBoxReturn =
{
    OK = 1,
    CANCEL = 2,
    ABORT = 3,
    RETRY = 4,
    IGNORE = 5,
    YES = 6,
    NO = 7
}

OperatingSystems = {
    Win32 = "Win32",
    Win64 = "Win64",
    OSX32 = "OSX32",
    OSX64 = "OSX64",
    macOSarm64 = "macOS-arm64",
    other = "Other"
}

function reaper.IsWinOs()
    local os <const> = reaper.GetOS()
    return
        os == OperatingSystems.Win32 or
        os == OperatingSystems.Win64
end

function reaper.IsMacOS()
    local os <const> = reaper.GetOS()
    return
        os == OperatingSystems.OSX32 or
        os == OperatingSystems.OSX64 or
        os == OperatingSystems.macOSarm64
end

function reaper.IsLinuxOS()
    return not reaper.IsWinOs() and not reaper.IsMacOS() -- may change in future?
end

function reaper.BuildPeaks()
    reaper.Main_OnCommandEx(40245, 0, THIS_PROJECT) -- Peaks: Build any missing peaks for selected items
end

reaper.AudioFormats = { "WAV", "AIFF", "FLAC", "MP3", "OGG", "BWF", "W64", "WAVPACK" }

reaper.UndoState = {
    All = -1,
    TrackCFG = 1 << 0,   -- track/master vol/pan/routing, routing/hwout envelopes too
    FX = 1 << 1,         -- track/master fx
    Items = 1 << 2,      -- track items
    MiscCFG = 1 << 3,    -- loop selection, markers, regions, extensions
    Freeze = 1 << 4,     -- freeze state
    TrackENV = 1 << 5,   -- non-FX envelopes only
    FxENV = 1 << 6,      -- FX envelopes, implied by UNDO_STATE_FX too
    PooledENVS = 1 << 7, -- contents of automation items -- not position, length, rate etc of automation items, which is part of envelope state
    ARA = 1 << 8         -- ARA state
}

--#region ActionBase

Action = Object:extend()

function Action:Begin()
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    Debug:Log("Action Begin\n")
end

function Action:Complete(undoState)
    undoState = undoState or -1
    reaper.Undo_EndBlock(self.undoText, undoState);
    reaper.PreventUIRefresh(-1)
    reaper.BuildPeaks()
    Debug:Log("Action Complete: %s\n", self.undoText)
end

function Action:Cancel()
    reaper.Undo_DoUndo2(THIS_PROJECT)
    reaper.PreventUIRefresh(-1)
    Debug:Log("Action Cancel\n")
end

--#endregion

--#region Container

Container = Object:extend()

function Container:new(fillType)
    self.array = {}

    if fillType == FillType.Selected then
        self:FillSelected()
    elseif fillType == FillType.All then
        self:FillAll()
    end
end

function Container:FillAll()
    reaper.log("Container:FillAll() should be overridden")
end

function Container:FillSelected()
    reaper.log("Container:FillSelected() should be overridden")
end

function Container:IsEmpty()
    return #self.array <= 0
end

function Container:At(index)
    return self.array[index]
end

function Container:Start()
    return self.array[1]
end

function Container:End()
    return self.array[#self.array]
end

function Container:Size()
    return #self.array
end

--#endregion Container

--#region Project

THIS_PROJECT = 0

FillType = {
    None = 0,
    Selected = 1,
    All = 2,
}

FadeDirection = {
    In = 0,
    Out = 1,
}

FadeShape = {
    linear = 0,
    fastStart = 1,
    fastEnd = 2,
    fastStartSteep = 3,
    fastEndSteep = 4,
    slowStartEnd = 5,
    slowStartEndSteep = 6,
    max = 7
}

function FadeShape.GetName(index)
    if index == FadeShape.linear then
        return "Linear"
    elseif index == FadeShape.fastStart then
        return "Fast Start"
    elseif index == FadeShape.fastEnd then
        return "Fast End"
    elseif index == FadeShape.fastStartSteep then
        return "Fast Start Steep"
    elseif index == FadeShape.fastEndSteep then
        return "Fast End Steep"
    elseif index == FadeShape.slowStartEnd then
        return "Slow Start End"
    elseif index == FadeShape.slowStartEndSteep then
        return "Slow Start End Steep"
    else
        reaper.ShowConsoleMsg("FadeShape index is out of range\n")
        return ""
    end
end

Project = Object:extend()

function Project:new(ptr)
    self.ptr = ptr or 0
    self.markerList = {}
    self.regionList = {}
end

function Project:CountSelectedItems()
    return reaper.CountSelectedMediaItems(self.ptr)
end

function Project:SelectAll() reaper.SelectAllMediaItems(THIS_PROJECT, true) end

function Project:DeselectAll() reaper.SelectAllMediaItems(THIS_PROJECT, false) end

function Project:FillRegionsAndMarkers()
    local markerCount <const> = reaper.CountProjectMarkers(THIS_PROJECT)

    table.clear(self.regionList)
    table.clear(self.markerList)

    for i = 0, markerCount, 1 do
        local _, isRegion <const>, startPos <const>, endPos <const>, name <const>, index <const> =
            reaper.EnumProjectMarkers(i)

        if isRegion then
            table.insert(self.regionList, { index = index, name = name, startPos = startPos })
        else
            table.insert(self.markerList, { index = index, name = name, startPos = startPos, endPos = endPos })
        end
    end
end

function Project:GetSpecialRegions()
    local specialRegions = {}
    self:FillRegionsAndMarkers()

    for _, region in pairs(self.regionList) do
        if string.find(region.name, "=") then
            table.insert(specialRegions, region)
        end
    end

    return specialRegions
end

--#endregion Project

--#region Marker

Marker = Object:extend()

function Marker:new(index, name, position)
    self.index = index
    self.name = name
    self.position = position
end

function Marker:GetName() return self.name end

function Marker:GetPosition() return self.position end

function Marker:GetIndex() return self.index end

function Marker:SetName(name)
    reaper.SetProjectMarker(self.index, false, self.position, 0, name)
end

--#endregion

--#region Markers

Markers = Container:extend()

function Markers:new(fillType)
    Tracks.super.new(self, fillType)
end

function Markers:FillAll()
    local _, markerCount <const>, _ = reaper.CountProjectMarkers(THIS_PROJECT)
    for i = 1, markerCount do
        local _, isRegion <const>, position <const>, _, name <const>, index <const> = reaper.EnumProjectMarkers(i - 1)
        if not isRegion then
            local marker <const> = Marker(index, name, position)
            table.insert(self.array, marker)
        end
    end
end

--#endregion Markers

--#region Track

Track = Object:extend()

function Track:new(ptr)
    if ptr == nil then reaper.ShowConsoleMsg("NULL Media Track\n" .. debug.traceback() .. "\n") end
    self.ptr = ptr
end

function Track:CreateBlankItem(name, position, length)
    local item <const> = Item(reaper.AddMediaItemToTrack(self.ptr))
    item:CreateBlankTake(name)
    item:SetNotes(name)
    item:SetPosition(position)
    item:SetLength(length)
    return item
end

function Track:CreateNewItem(name, position)
    local item <const> = Item(reaper.AddMediaItemToTrack(self.ptr))
    local take <const> = item:CreateNewTake(name)
    item:SetPosition(position)
    item:SetLength(take:GetSourceLength())
    return item
end

function Track:GetPrimogenitorPtr() -- Gets the most parent track
    local track = self.ptr
    while reaper.GetParentTrack(track) do
        track = reaper.GetParentTrack(track)
    end
    return track
end

function Track:DeleteItems()
    for i = reaper.CountTrackMediaItems(self.ptr), 1, -1 do -- reverse
        local item <const> = reaper.GetTrackMediaItem(self.ptr, i)
        if item then reaper.DeleteTrackMediaItem(self.ptr, item) end
    end
end

--#region Wrappers

function Track:SetName(name) reaper.GetSetMediaTrackInfo_String(self.ptr, "P_NAME", name, true) end

-- depth: 0 = normal, 1 = parent, -1 = last in the innermost folder, -2 = track is the last in the innermost and next - innermost folders, etc
function Track:SetFolderDepth(depth) reaper.SetMediaTrackInfo_Value(self.ptr, "I_FOLDERDEPTH", depth) end

function Track:GetFolderDepth() return reaper.GetMediaTrackInfo_Value(self.ptr, "I_FOLDERDEPTH") end

function Track:GetDepth() return reaper.GetTrackDepth(self.ptr) end

function Track:IsRoot() return self:GetDepth() == 0 end

function Track:__tostring()
    return select(2, reaper.GetSetMediaTrackInfo_String(self.ptr, "P_NAME", "", false))
end

--#endregion Wrappers

--#endregion Track

--#region TrackList

Tracks = Container:extend()

function Tracks:new(fillType)
    Tracks.super.new(self, fillType)
end

function Tracks:FillSelected()
    for i = 1, reaper.CountSelectedTracks(THIS_PROJECT) do
        local track <const> = Track(reaper.GetSelectedTrack(THIS_PROJECT, i - 1))
        table.insert(self.array, track)
    end
end

function Tracks:FillAll()
    for i = 1, reaper.CountTracks(THIS_PROJECT) do
        local track <const> = Track(reaper.GetTrack(THIS_PROJECT, i - 1))
        table.insert(self.array, track)
    end
end

function Tracks:CreateNew(name)
    local wantDefaults <const> = false
    reaper.InsertTrackAtIndex(self:Size(), wantDefaults)
    local track <const> = Track(reaper.GetTrack(THIS_PROJECT, self:Size()))
    track:SetName(name)
    table.insert(self.array, track)
end

--#endregion TrackList

--#region Item

Item = Object:extend()

function Item:new(ptr)
    if ptr == nil then reaper.ShowConsoleMsg("NULL Media Item\n" .. debug.traceback() .. "\n") end
    self.ptr = ptr
    self.takes = self:GetTakes()
end

--#region Wrappers

function Item:__eq(other) return self.ptr == other.ptr end

function Item:__tostring() return select(2, reaper.GetSetMediaItemInfo_String(self.ptr, "P_NOTES", "", false)) end

function Item:GetActiveTakePtr() return reaper.GetActiveTake(self.ptr) end

function Item:GetColor() return reaper.GetMediaItemInfo_Value(self.ptr, "I_CUSTOMCOLOR") end

function Item:GetLength() return reaper.GetMediaItemInfo_Value(self.ptr, "D_LENGTH") end

function Item:GetEnd() return self:GetStart() + self:GetLength() end

function Item:GetGUID() return reaper.BR_GetMediaItemGUID(self.ptr) end

function Item:GetStart() return reaper.GetMediaItemInfo_Value(self.ptr, "D_POSITION") end

function Item:GetSnapOffset() return reaper.GetMediaItemInfo_Value(self.ptr, "D_SNAPOFFSET") end

function Item:GetTrackPtr() return reaper.GetMediaItemTrack(self.ptr) end

function Item:GetVolume() return Maths.VOL2DB(reaper.GetMediaItemInfo_Value(self.ptr, "D_VOL")) end

function Item:GetFadeInLength() return reaper.GetMediaItemInfo_Value(self.ptr, "D_FADEINLEN") end

function Item:GetFadeOutLength() return reaper.GetMediaItemInfo_Value(self.ptr, "D_FADEOUTLEN") end

function Item:Select() reaper.SetMediaItemSelected(self.ptr, true) end

function Item:SetDeselected() reaper.SetMediaItemSelected(self.ptr, false) end

function Item:SetFadeInLength(seconds) reaper.SetMediaItemInfo_Value(self.ptr, "D_FADEINLEN", seconds) end

function Item:SetFadeInShape(fadeShape) reaper.SetMediaItemInfo_Value(self.ptr, "C_FADEINSHAPE", fadeShape) end

function Item:SetFadeOutLength(seconds) reaper.SetMediaItemInfo_Value(self.ptr, "D_FADEOUTLEN", seconds) end

function Item:SetFadeOutShape(fadeShape) reaper.SetMediaItemInfo_Value(self.ptr, "C_FADEOUTSHAPE", fadeShape) end

function Item:SetLength(seconds) reaper.SetMediaItemInfo_Value(self.ptr, "D_LENGTH", seconds or 0) end

function Item:SetNotes(notes) reaper.GetSetMediaItemInfo_String(self.ptr, "P_NOTES", notes, true) end

function Item:SetPosition(seconds) reaper.SetMediaItemInfo_Value(self.ptr, "D_POSITION", seconds or 0) end

function Item:SetSelected() reaper.SetMediaItemSelected(self.ptr, true) end

function Item:SetSnapOffset(seconds) reaper.SetMediaItemInfo_Value(self.ptr, "D_SNAPOFFSET", seconds or 0) end

function Item:SetTrack(trackPtr) reaper.MoveMediaItemToTrack(self.ptr, trackPtr) end

function Item:SetVolume(dB) reaper.SetMediaItemInfo_Value(self.ptr, "D_VOL", Maths.DB2VOL(dB)) end

function Item:Unselect() reaper.SetMediaItemSelected(self.ptr, false) end

--#endregion Wrappers

function Item:ClearOffset()
    self:SetPosition(self:GetStart() + self:GetSnapOffset())
    self:SetLength(self:GetLength() - self:GetSnapOffset())

    for _, take in pairs(self.takes) do
        take:SetStartOffset(take:GetStartOffset() + self:GetSnapOffset())
    end

    self:SetSnapOffset(0)
end

function Item:CreateBlankTake(name)
    local take <const> = Take(reaper.AddTakeToMediaItem(self.ptr))
    take:SetName(name)
    return take
end

function Item:CreateNewTake(path)
    local take <const> = Take(reaper.AddTakeToMediaItem(self.ptr))
    take:SetAudioSource(path)

    local _, fileName <const>, _ = FileSys.Path.Parse(path)
    take:SetName(fileName)
    return take
end

function Item:GetTakes()
    local takes <const> = {}
    for i = 1, reaper.CountTakes(self.ptr), 1 do
        local take <const> = Take(reaper.GetTake(self.ptr, i - 1))
        table.insert(takes, take)
    end
    return takes
end

--#endregion Item

--#region ItemList

Items = Container:extend()

function Items:new(fillType)
    Items.super.new(self, fillType)
end

function Items:FillSelected()
    table.clear(self.array)
    for i = 1, reaper.CountSelectedMediaItems(THIS_PROJECT) do
        local item <const> = Item(reaper.GetSelectedMediaItem(THIS_PROJECT, i - 1))
        table.insert(self.array, item)
    end
    self.size = #self.array
end

function Items:FillAll()
    table.clear(self.array)
    for i = 1, reaper.CountMediaItems(THIS_PROJECT) do
        local item <const> = Item(reaper.GetMediaItem(THIS_PROJECT, i - 1))
        table.insert(self.array, item)
    end
    self.size = #self.array
end

--#endregion ItemList

--#region Take

Take = Object:extend()

function Take:new(ptr)
    if ptr == nil then reaper.ShowConsoleMsg("NULL Media Take\n" .. debug.traceback() .. "\n") end
    self.ptr = ptr
end

--#region Wrappers

function Take:__tostring() return select(2, reaper.GetSetMediaItemTakeInfo_String(self.ptr, "P_NAME", "", false)) end

function Take:GetStartOffset() return reaper.GetMediaItemTakeInfo_Value(self.ptr, "D_STARTOFFS") end

function Take:SetName(name) reaper.GetSetMediaItemTakeInfo_String(self.ptr, "P_NAME", name, true) end

function Take:GetSourcePtr() return reaper.GetMediaItemTake_Source(self.ptr) end

function Take:GetTrackPtr() return reaper.GetMediaItemTake_Track(self.ptr) end

function Take:SetStartOffset(seconds) reaper.SetMediaItemTakeInfo_Value(self.ptr, "D_STARTOFFS", seconds) end

function Take:GetVolume() return Maths.VOL2DB(reaper.GetMediaItemTakeInfo_Value(self.ptr, "D_VOL")) end

function Take:SetVolume(dB) reaper.SetMediaItemTakeInfo_Value(self.ptr, "D_VOL", Maths.DB2VOL(dB)) end

function Take:GetSourceProperties() return reaper.BR_GetMediaSourceProperties(self.ptr) end

function Take:SetSourceProperties(section, start, length, fade, reverse)
    reaper.BR_SetMediaSourceProperties(self.ptr, section, start, length, fade, reverse)
end

--#endregion Wrappers

function Take:GetSourceLength()
    local source <const> = reaper.GetMediaItemTake_Source(self.ptr)
    local length <const> = reaper.GetMediaSourceLength(source)
    return length
end

function Take:SetAudioSource(path)
    local oldSource <const> = reaper.GetMediaItemTake_Source(self.ptr)
    local newSource <const> = reaper.PCM_Source_CreateFromFile(path)

    if newSource ~= nil then
        reaper.SetMediaItemTake_Source(self.ptr, newSource)
    else
        reaper.log("Source with dir '{%s}' is nil", path)
    end

    if oldSource ~= nil then
        reaper.PCM_Source_Destroy(oldSource)
    end
end

--#endregion Take

--#region Source

NormalizationType = {
    LUFS_I = 0,
    RMS = 1,
    PEAK = 2,
    TRUE_PEAK = 3,
    LUFS_M = 4,
    LUFS_S = 5,
}

Source = Object:extend()

function Source:new(ptr)
    if ptr == nil then reaper.log("NULL PCM_source\n" .. debug.traceback()) end
    self.ptr = ptr
end

function Source:IsValid()
    return reaper.GetMediaSourceType(self.ptr) ~= "EMPTY" and self:GetSampleRate() > 0
end

function Source:GetPath()
    local fileName <const> = reaper.GetMediaSourceFileName(self.ptr)
    return fileName
end

function Source:GetFileFormat()
    local _, _, ext <const> = FileSys.Path.Parse(self:GetPath())
    return ext
end

function Source:GetFileName()
    local _, fileName <const>, _ = FileSys.Path.Parse(self:GetPath())
    return fileName
end

function Source:__tostring()
    local _, fileName <const>, _ = FileSys.Path.Parse(self:GetPath())
    return fileName
end

function Source:GetChannelCount()
    return reaper.GetMediaSourceNumChannels(self.ptr)
end

function Source:GetSampleRate()
    return reaper.GetMediaSourceSampleRate(self.ptr)
end

function Source:GetBitDepth()
    return reaper.CF_GetMediaSourceBitDepth(self.ptr)
end

function Source:GetLength() return reaper.GetMediaSourceLength(self.ptr) end

function Source:GetNormalization(normalizationType)
    return 20 * math.log(reaper.CalculateNormalization(self.ptr, normalizationType, 0, 0, 0), 10) * -1
end

function Source:GetPeak() return self:GetNormalization(NormalizationType.PEAK) end

function Source:GetRMS() return self:GetNormalization(NormalizationType.RMS) end

function Source:GetLUFS() return self:GetNormalization(NormalizationType.LUFS_I) end

function Source:GetTimeToPeak(bufferSize, threshold)
    return reaper.GU_PCM_Source_TimeToPeak(self.ptr, bufferSize, threshold)
end

function Source:GetTimeToPeakR(bufferSize, threshold)
    return reaper.GU_PCM_Source_TimeToPeakR(self.ptr, bufferSize, threshold)
end

function Source:GetTimeToRMS(bufferSize, threshold)
    return reaper.GU_PCM_Source_TimeToRMS(self.ptr, bufferSize, threshold)
end

function Source:GetTimeToRMSR(bufferSize, threshold)
    return reaper.GU_PCM_Source_TimeToRMSR(self.ptr, bufferSize, threshold)
end

function Source:IsFirstSampleZero(eps)
    local value <const> = math.abs(reaper.GU_PCM_Source_GetSampleValue(self.ptr, 0))
    return Maths.IsNearlyEqual(value, 0, eps)
end

function Source:IsLastSampleZero(eps)
    local length <const> = self:GetLength()
    local value <const> = math.abs(reaper.GU_PCM_Source_GetSampleValue(self.ptr, length))
    return Maths.IsNearlyEqual(value, 0, eps)
end

function Source:HasLoopMarker() return reaper.GU_PCM_Source_HasRegion(self.ptr) end

function Source:IsMono() return reaper.GU_PCM_Source_IsMono(self.ptr) end

--#endregion Source

--#region TakeList

Takes = Container:extend()

function Takes:new(fillType)
    Tracks.super.new(self, fillType)
end

function Takes:FillSelected()
    -- to overwrite
end

function Takes:FillAll()
    -- to overwrite
end

--#endregion TakeList

--#region Curve

Curve = Object:extend()

function Curve:new(size)
    self.size = size or 32
    self.plot = {}
end

function Curve:ScaleAndClamp()
    local first <const> = self.plot[1]
    local last <const> = self.plot[#self.plot]

    for i = 1, self.size do
        self.plot[i] = (self.plot[i] - first) * (self.size / (last - first))
    end
    return self.plot
end

function Curve:PlotBlank()
    for i = 1, self.size do
        self.plot[i] = 0
    end

    return self:ScaleAndClamp()
end

function Curve:PlotLinear()
    for i = 1, self.size do
        local index <const> = i - 1
        self.plot[i] = index
    end

    return self:ScaleAndClamp()
end

function Curve:PlotLinearR()
    self:PlotLinear()
    return self:ReversePlot()
end

function Curve:PlotFastStart(steepness)
    for i = 1, self.size do
        local index <const> = i - 1
        self.plot[i] = self.size * (1 - (((self.size - index) / self.size) ^ steepness))
    end

    return self:ScaleAndClamp()
end

function Curve:PlotFastStartR(steepness)
    self:PlotFastStart(steepness)
    return self:ReversePlot()
end

function Curve:PlotFastEnd(steepness)
    for i = 1, self.size do
        local index <const> = i - 1
        self.plot[i] = self.size * ((index / self.size) ^ steepness)
    end

    return self:ScaleAndClamp()
end

function Curve:PlotFastEndR(steepness)
    self:PlotFastEnd(steepness)
    return self:ReversePlot()
end

function Curve:PlotSlowStartEnd(steepness)
    local halfSize = self.size * 0.5
    for i = 1, self.size do
        local index <const> = i - 1
        self.plot[i] = halfSize * (Maths.Erf(steepness * (index - halfSize) / self.size) + 1)
    end

    return self:ScaleAndClamp()
end

function Curve:PlotSlowStartEndR(steepness)
    self:PlotSlowStartEnd(steepness)
    return self:ReversePlot()
end

function Curve:ReversePlot()
    for i = 1, math.floor(self.size / 2) do
        local j <const> = self.size - i + 1
        self.plot[i], self.plot[j] = self.plot[j], self.plot[i]
    end

    return self.plot
end

--#endregion Curve
