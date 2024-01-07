-- @description Item renamer
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Batch renames items using similar wildcards annotation as in Reaper's own Render dialog.

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/gui_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")

--#region Wildcard

Wildcard = Object:extend()

function Wildcard:new(tag, tooltip)
    self.tag = tag
    self.tooltip = tooltip
end

Wildcards = Object:extend()
Wildcards.Year2 = Wildcard("year2", "The current year as YY")
Wildcards.YEAR2 = Wildcard("$year2", "The current year as YY")
Wildcards.YEAR = Wildcard("$year", "The current year as YYYY")
Wildcards.TRACKX = Wildcard("$track(%s)",
    "Name of Track that is x levels higher than Item's current Track. X is capped at outermost Track\n\n*supports mousewheel scroll*")
Wildcards.TRACKTOP = Wildcard("$tracktop", "Name of outermost parent Track for Item")
Wildcards.TRACKNUMBER = Wildcard("$tracknumber", "Number of Track that Item is on")
Wildcards.TRACK = Wildcard("$track", "Name of Track that Item is on")
Wildcards.TIMESIG = Wildcard("$timesignature",
    "Tempo marker time signature value nearest to the left edge of a given Item")
Wildcards.TIME = Wildcard("$time", "The current time as hh-mm-ss")
Wildcards.TEMPO = Wildcard("$tempo", "Tempo marker BPM value nearest to the left of Item's left edge")
Wildcards.SECOND = Wildcard("$second", "The current second as ss")
Wildcards.RMS = Wildcard("$rms",
    "Returns the average overall(non - windowed) RMS level of active channels of an audio item active take, post item gain, post take volume envelope, post - fade, pre fader, pre item FX")
Wildcards.REGIONX = Wildcard("$region(%s)",
    "Name of Region surrounding Item whose tag prepended by \"=\" is specifed in brackets\n\ne.g. If a Region is named \"type=drum\"\nusing wildcard \"$region(type)\"\nwill produce the result \"drum\"")
Wildcards.REGION = Wildcard("$region", "Name of Region whose start position is nearest to the left edge of Item's edge")
Wildcards.PROJECT = Wildcard("$project", "Name of current Project. This is the name of the .rpp on disk")
Wildcards.PEAK = Wildcard("$peak",
    "Max peak value of all active channels of an audio item active take, post item gain, post take volume envelope, post-fade, pre fader, pre item FX")
Wildcards.MONTHNAME = Wildcard("$monthname", "The current month's name")
Wildcards.MONTH = Wildcard("$month", "The current month as MM")
Wildcards.MINUTE = Wildcard("$minute", "The current minute as mm")
Wildcards.MARKER = Wildcard("$marker", "Name of Marker nearest to the left of Item's left edge")
Wildcards.LUFS = Wildcard("$lufs", "Integrated loudness of Item as dBFS")
--Wildcards.ITEMNUMBERX = Wildcard("($itemnumber\( = Wildcard(}\))", "Item number in selection")
--Wildcards.ITEMNUMBERONTRACKX = Wildcard(R "($itemnumberontrack\( = Wildcard(}\))", "Item number in selection, per Track")
Wildcards.ITEMNUMBERONTRACK = Wildcard("$itemnumberontrack", "Item number in selection, per Track")
Wildcards.ITEMNUMBER = Wildcard("$itemnumber", "Item number in selection")
Wildcards.ITEMNOTES = Wildcard("$itemnotes", "String consisting of Item's Notes")
--Wildcards.ITEMCOUNTX = Wildcard("($itemcount\( = Wildcard(}\))", "Total quantity of selected Items")
Wildcards.ITEMCOUNT = Wildcard("$itemcount", "Total quantity of selected Items")
Wildcards.ITEM = Wildcard("$item", "Name of Item's Active Take")
Wildcards.HOUR12 = Wildcard("$hour12", "The current hour in 12 hour format")
Wildcards.HOUR = Wildcard("$hour", "The current hour in 24 hour format")
Wildcards.FXX = Wildcard("$fx(%s)",
    "A list of all FX on Item, separated by a custom character\n\n*supports mousewheel scroll*")
Wildcards.FX = Wildcard("$fx", "A list of all FX on Item, separated by underscores")
Wildcards.DAYNAME = Wildcard("$dayname", "The current day's name")
Wildcards.DAY = Wildcard("$day", "The current day as DD")
Wildcards.DATE = Wildcard("$date", "The current date as YY-MM-DD")
Wildcards.AUTHOR = Wildcard("$author", "Name of Project Author. Set in Project Settings -> Notes")
Wildcards.AMPM = Wildcard("$ampm", "The current time of day as AM or PM")

--#endregion

--#region WildcardReplacements

WildcardReplacement = Object:extend()

function WildcardReplacement:new(wildcard, replacement)
    self.wildcard = wildcard
    self.replacement = replacement
end

--#endregion WildcardReplacements

--#region ItemRenamer

ItemRenamer = GuiBase:extend()

ItemRenamer.DefaultItemNumber = 1

ItemRenamer.Error = {
    NO_ITEM_SELECTION = "-- No items selected --",
    NO_AUTHOR = "-- No Project Author set --",
    NO_PROJECT_ON_DISK = "-- Project not saved --",
    NO_REGION = "-- No region for first item --",
    NO_SPECIAL_REGION = "-- No special regions in project --",
    NO_MARKER = "-- No marker for first item --",
    NO_FX = "-- No FX for active item --",
    NO_ACTIVE_TAKE = "-- Item missing active take --",
    NO_TAKE_NOTES = "-- Take has no notes --",
    NO_AUDIO_SOURCE = "-- Take is missing audio source --"
}

function ItemRenamer:new(name, undoText)
    ItemRenamer.super.new(self, name, undoText)

    self.windowFlags = self.windowFlags + reaper.ImGui_WindowFlags_MenuBar()

    self.configKey = "replacementString"
    self.config = Config(FileSys.GetRawName(name))

    local value = self.config:Read(self.configKey)

    self.items = Items(FillType.Selected)
    self.input = value or ""

    self.separatorList = { "-", " ", "_", "+", "=" }

    -- selectors
    self.TrackXSelector = 0
    self.RegionXSelector = 0
    self.FxXSelector = 0

    self.windowWidth = 400
    self.windowHeight = 96
end

function ItemRenamer:ProcessItems()
    local itemNumberOnTrack = 0
    local currentTrack = nil
    for i, item in pairs(self.items.array) do
        local takePtr <const> = item:GetActiveTakePtr()

        if takePtr == nil then goto continue end

        local take <const> = Take(takePtr)
        local newTrack = take:GetTrackPtr()
        assert(newTrack ~= nil, "All Takes belong to a Track")

        if currentTrack ~= newTrack then
            currentTrack = newTrack
            itemNumberOnTrack = 0
        end

        itemNumberOnTrack = itemNumberOnTrack + 1

        local value = self.input
        value = self:LocalWildcardParseTake(value, i, itemNumberOnTrack)
        value = reaper.GU_WildcardParseTake(takePtr, value)
        take:SetName(value)

        ::continue::
    end

    self.config:Write(self.configKey, self.input)
end

function ItemRenamer:LocalWildcardParseTake(value, itemNumber, itemNumberOnTrack)
    local itemCount <const> = Project():CountSelectedItems()

    local wildcardReplacements <const> =
    {
        WildcardReplacement("$itemnumberontrack%[", itemNumberOnTrack),
        WildcardReplacement("$itemnumber%[", itemNumber),
        WildcardReplacement("$itemcount%[", itemCount),
    }

    for _, info in pairs(wildcardReplacements) do
        while true do
            local startPos <const>, endBracket = string.find(value, info.wildcard)

            if startPos == nil then break end

            endBracket = string.find(value, "%]", endBracket)

            if endBracket == nil then break end

            local tag = tostring(string.sub(value, startPos + string.len(info.wildcard) - 1,
                endBracket - 1))

            local toReplace = string.sub(value, startPos, endBracket)
            toReplace = toReplace:gsub("[%[%]-]", "%%%1") -- escapes square brackets and negative sign

            ---@diagnostic disable-next-line: param-type-mismatch
            local replacement = GUtil.IsInt(tag) and
                tostring(tonumber(tag) - 1 + info.replacement) or
                tostring(info.replacement)

            local replacementNumber <const> = tonumber(replacement)
            replacement = (replacementNumber and replacementNumber < 0) and
                "-" .. string.rep("0", #tag - #replacement - 1) .. math.abs(replacementNumber) or
                string.rep("0", #tag - #replacement) .. replacement

            value = value:gsub(toReplace, tostring(replacement))
        end
    end

    -- then do regular
    value = value:gsub("$itemnumberontrack", tostring(itemNumberOnTrack))
    value = value:gsub("$itemnumber", tostring(itemNumber))
    value = value:gsub("$itemcount", tostring(itemCount))
    return value
end

function ItemRenamer:DrawMenuItemTooltip(tooltip, info, selector)
    selector = selector or 0
    if reaper.ImGui_IsItemHovered(self.ctx) then
        local verticalOut <const>, _ = reaper.ImGui_GetMouseWheel(self.ctx);

        if verticalOut > 0 then
            selector = selector + 1
        end
        if verticalOut < 0 then
            selector = selector - 1
        end

        reaper.ImGui_SetNextWindowSize(self.ctx, 200.0, 0.0)
        reaper.ImGui_BeginTooltip(self.ctx)
        local textWrapPos <const> = 0.0 -- 0.0: wrap to end of window (or column)
        reaper.ImGui_PushTextWrapPos(self.ctx, textWrapPos)

        reaper.ImGui_Text(self.ctx, tooltip .. "\n\n" .. info)
        reaper.ImGui_PopTextWrapPos(self.ctx)
        reaper.ImGui_EndTooltip(self.ctx)
    end

    return selector
end

function ItemRenamer:DrawMenuItem(wildcard, info)
    if reaper.ImGui_MenuItem(self.ctx, wildcard.tag) then
        self.input = self.input .. wildcard.tag
    end

    self:DrawMenuItemTooltip(wildcard.tooltip, info)
end

function ItemRenamer:DrawSpecialMenuItemString(wildcard, info, selector)
    local specialtag = string.format(wildcard.tag, info.input)
    if reaper.ImGui_MenuItem(self.ctx, specialtag) then
        self.input = self.input .. specialtag
    end

    return self:DrawMenuItemTooltip(wildcard.tooltip, info.output, selector)
end

function ItemRenamer:DrawSpecialMenuItemNumber(wildcard, info, selector)
    local specialtag = string.format(wildcard.tag, selector)
    if reaper.ImGui_MenuItem(self.ctx, specialtag) then
        self.input = self.input .. specialtag
    end

    return self:DrawMenuItemTooltip(wildcard.tooltip, info, selector)
end

function ItemRenamer:PrintProjectName()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    local value <const> = reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), Wildcards.PROJECT.tag)
    return GUtil.IsNilOrEmpty(value) and ItemRenamer.Error.NO_PROJECT_ON_DISK or value
end

function ItemRenamer:PrintAuthorName()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    local value <const> = reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), Wildcards.AUTHOR.tag)
    return GUtil.IsNilOrEmpty(value) and ItemRenamer.Error.NO_AUTHOR or value
end

function ItemRenamer:PrintItemNotes()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    local value <const> = reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), Wildcards.ITEMNOTES.tag)
    return GUtil.IsNilOrEmpty(value) and ItemRenamer.Error.NO_TAKE_NOTES or value
end

function ItemRenamer:PrintRegion()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    local regionName <const> = reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), Wildcards.REGION.tag)
    return GUtil.IsNilOrEmpty(regionName) and ItemRenamer.Error.NO_REGION or regionName
end

function ItemRenamer:PrintMarker()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    local markerName <const> = reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), Wildcards.MARKER.tag)
    return GUtil.IsNilOrEmpty(markerName) and ItemRenamer.Error.NO_MARKER or markerName
end

function ItemRenamer:PrintTakeFx()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    if self.items:Start():GetActiveTakePtr() == nil then return ItemRenamer.Error.NO_ACTIVE_TAKE end
    local fxList <const> = reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), Wildcards.FX.tag)
    return GUtil.IsNilOrEmpty(fxList) and ItemRenamer.Error.NO_FX or fxList
end

function ItemRenamer:PrintTag(wildcard)
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    return reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), wildcard.tag)
end

function ItemRenamer:PrintLUFS()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    if self.items:Start():GetActiveTakePtr() == nil then return ItemRenamer.Error.NO_ACTIVE_TAKE end
    if Take(self.items:Start():GetActiveTakePtr()):GetSourcePtr() == nil then return ItemRenamer.Error.NO_AUDIO_SOURCE end
    return reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), Wildcards.LUFS.tag)
end

function ItemRenamer:PrintPeak()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    if self.items:Start():GetActiveTakePtr() == nil then return ItemRenamer.Error.NO_ACTIVE_TAKE end
    if Take(self.items:Start():GetActiveTakePtr()):GetSourcePtr() == nil then return ItemRenamer.Error.NO_AUDIO_SOURCE end
    return reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), Wildcards.LUFS.tag)
end

function ItemRenamer:PrintRMS()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end
    if self.items:Start():GetActiveTakePtr() == nil then return ItemRenamer.Error.NO_ACTIVE_TAKE end
    if Take(self.items:Start():GetActiveTakePtr()):GetSourcePtr() == nil then return ItemRenamer.Error.NO_AUDIO_SOURCE end
    return reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(), Wildcards.LUFS.tag)
end

function ItemRenamer:PrintTrackX()
    if self.items:IsEmpty() then return ItemRenamer.Error.NO_ITEM_SELECTION end

    self.TrackXSelector = Maths.Clamp(self.TrackXSelector, 0, Int32.max);

    return reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(),
        string.format(Wildcards.TRACKX.tag, self.TrackXSelector))
end

function ItemRenamer:PrintRegionX()
    if self.items:IsEmpty() then return { input = "", output = ItemRenamer.Error.NO_ITEM_SELECTION } end
    local specialRegions <const> = Project():GetSpecialRegions()

    if (table.isEmpty(specialRegions)) then return { input = "", output = ItemRenamer.Error.NO_SPECIAL_REGION } end

    self.RegionXSelector = Maths.Clamp(self.RegionXSelector, 1, #specialRegions);

    local regionName <const> = specialRegions[self.RegionXSelector].name
    local equalsPos <const> = string.find(regionName, "=");
    local regionPreEquals <const> = string.sub(regionName, 0, equalsPos - 1)

    return
    {
        input = regionPreEquals,
        output = reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(),
            string.format(Wildcards.REGIONX.tag, regionPreEquals))
    }
end

function ItemRenamer:PrintTakeFxX()
    if self.items:IsEmpty() then return { input = "", output = ItemRenamer.Error.NO_ITEM_SELECTION } end
    if self.items:Start():GetActiveTakePtr() == nil then return { input = "", output = ItemRenamer.Error.NO_ACTIVE_TAKE } end

    if self.FxXSelector < 1 then self.FxXSelector = #self.separatorList end
    if self.FxXSelector > #self.separatorList then self.FxXSelector = 1 end

    local separator <const> = self.separatorList[self.FxXSelector]

    local fxList <const> = reaper.GU_WildcardParseTake(self.items:Start():GetActiveTakePtr(),
        string.format(Wildcards.FXX.tag, separator))

    if (GUtil.IsNilOrEmpty(fxList)) then return { input = "", output = ItemRenamer.Error.NO_FX } end
    return { input = separator, output = fxList }
end

function ItemRenamer:DrawMenu()
    if reaper.ImGui_BeginMenuBar(self.ctx) then
        if reaper.ImGui_BeginMenu(self.ctx, "Wildcards") then
            if reaper.ImGui_BeginMenu(self.ctx, "Project Information") then
                self:DrawMenuItem(Wildcards.PROJECT, self:PrintProjectName())
                self:DrawMenuItem(Wildcards.AUTHOR, self:PrintAuthorName())
                self:DrawMenuItem(Wildcards.TRACKNUMBER, self:PrintTag(Wildcards.TRACKNUMBER))
                self:DrawMenuItem(Wildcards.TRACK, self:PrintTag(Wildcards.TRACK))
                self.TrackXSelector = self:DrawSpecialMenuItemNumber(Wildcards.TRACKX, self:PrintTrackX(),
                    self.TrackXSelector)
                self:DrawMenuItem(Wildcards.TRACKTOP, self:PrintTag(Wildcards.TRACKTOP))
                self.RegionXSelector = self:DrawSpecialMenuItemString(Wildcards.REGIONX, self:PrintRegionX(),
                    self.RegionXSelector)
                self:DrawMenuItem(Wildcards.REGION, self:PrintRegion())
                self:DrawMenuItem(Wildcards.MARKER, self:PrintMarker())
                self:DrawMenuItem(Wildcards.TEMPO, self:PrintTag(Wildcards.TEMPO))
                self:DrawMenuItem(Wildcards.TIMESIG, self:PrintTag(Wildcards.TIMESIG))
                self.FxXSelector = self:DrawSpecialMenuItemString(Wildcards.FXX, self:PrintTakeFxX(),
                    self.FxXSelector)
                self:DrawMenuItem(Wildcards.FX, self:PrintTakeFx())
                reaper.ImGui_EndMenu(self.ctx)
            end
            if reaper.ImGui_BeginMenu(self.ctx, "Project Order") then
                self:DrawMenuItem(Wildcards.ITEMCOUNT, self:PrintTag(Wildcards.ITEMCOUNT))
                self:DrawMenuItem(Wildcards.ITEMNUMBER, ItemRenamer.DefaultItemNumber)
                self:DrawMenuItem(Wildcards.ITEMNUMBERONTRACK, ItemRenamer.DefaultItemNumber)
                reaper.ImGui_EndMenu(self.ctx)
            end
            if reaper.ImGui_BeginMenu(self.ctx, "Media Item Information") then
                self:DrawMenuItem(Wildcards.ITEM, self:PrintTag(Wildcards.ITEM))
                self:DrawMenuItem(Wildcards.ITEMNOTES, self:PrintItemNotes())
                reaper.ImGui_EndMenu(self.ctx)
            end
            if reaper.ImGui_BeginMenu(self.ctx, "Date/Time") then
                self:DrawMenuItem(Wildcards.DATE, self:PrintTag(Wildcards.DATE))
                self:DrawMenuItem(Wildcards.TIME, self:PrintTag(Wildcards.TIME))
                self:DrawMenuItem(Wildcards.YEAR, self:PrintTag(Wildcards.YEAR))
                self:DrawMenuItem(Wildcards.YEAR2, self:PrintTag(Wildcards.YEAR2))
                self:DrawMenuItem(Wildcards.MONTHNAME, self:PrintTag(Wildcards.MONTHNAME))
                self:DrawMenuItem(Wildcards.MONTH, self:PrintTag(Wildcards.MONTH))
                self:DrawMenuItem(Wildcards.DAYNAME, self:PrintTag(Wildcards.DAYNAME))
                self:DrawMenuItem(Wildcards.DAY, self:PrintTag(Wildcards.DAY))
                self:DrawMenuItem(Wildcards.HOUR, self:PrintTag(Wildcards.HOUR))
                self:DrawMenuItem(Wildcards.HOUR12, self:PrintTag(Wildcards.HOUR12))
                self:DrawMenuItem(Wildcards.AMPM, self:PrintTag(Wildcards.AMPM))
                self:DrawMenuItem(Wildcards.MINUTE, self:PrintTag(Wildcards.MINUTE))
                self:DrawMenuItem(Wildcards.SECOND, self:PrintTag(Wildcards.SECOND))
                reaper.ImGui_EndMenu(self.ctx);
            end
            if reaper.ImGui_BeginMenu(self.ctx, "Metering") then
                self:DrawMenuItem(Wildcards.LUFS, self:PrintLUFS())
                self:DrawMenuItem(Wildcards.PEAK, self:PrintPeak())
                self:DrawMenuItem(Wildcards.RMS, self:PrintRMS())
                reaper.ImGui_EndMenu(self.ctx)
            end
            reaper.ImGui_EndMenu(self.ctx);
        end
        reaper.ImGui_EndMenuBar(self.ctx);
    end
end

function ItemRenamer:Frame()
    local latestState <const> = reaper.GetProjectStateChangeCount(THIS_PROJECT)
    if self.lastProjectState ~= latestState then
        self.lastProjectState = latestState
        self.items:FillSelected()
    end

    self:DrawMenu()

    if self.frameCounter == 1 then
        reaper.ImGui_SetKeyboardFocusHere(self.ctx)
    end

    reaper.ImGui_PushItemWidth(self.ctx, -1);
    _, self.input = reaper.ImGui_InputText(self.ctx, " ", self.input)
    reaper.ImGui_PopItemWidth(self.ctx)

    if reaper.ImGui_Button(self.ctx, "Apply") or reaper.ImGui_IsEnterKeyPressed(self.ctx) then
        self:Begin()
        self:ProcessItems()
        self:Complete(reaper.UndoState.Items)
    end
end

--#endregion ItemRenamer

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = ItemRenamer(file, "Rename selected items")

reaper.defer(function() gui:Loop() end)
