-- @description Item renamer
-- @author guonaudio
-- @version 1.4
-- @changelog
--   Remove os lib (refactored into global)
--   Added "recent" list to allow recalling recently used strings
-- @about
--   Batch renames items using similar wildcards annotation as in Reaper's own Render dialog.

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_classic')
require('Lua.gutil_filesystem')
require('Lua.gutil_maths')
require('Lua.gutil_table')
require('Reaper.gutil_config')
require('Reaper.gutil_gui')
require('Reaper.gutil_item')
require('Reaper.gutil_project')
require('Reaper.gutil_source')
require('Reaper.gutil_take')
require('Reaper.gutil_track')

---@class Wildcard : Object
---@overload fun(tag: string, tooltip: string): Wildcard
---@operator call: Wildcard
Wildcard = Object:extend()

---@param tag string
---@param tooltip string
function Wildcard:new(tag, tooltip)
    self.tag = tag
    self.tooltip = tooltip
end

Wildcards = Object:extend()
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
Wildcards.MARKERX = Wildcard("$marker(%s)",
    "Name of Marker surrounding Item whose tag prepended by \"=\" is specifed in brackets\n\ne.g. If a Marker is named \"type=drum\"\nusing wildcard \"$marker(type)\"\nwill produce the result \"drum\"")
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

---@class WildcardReplacement : Object
WildcardReplacement = Object:extend()

---@param wildcard any
---@param replacement any
function WildcardReplacement:new(wildcard, replacement)
    self.wildcard = wildcard
    self.replacement = replacement
end

---@class ItemRenamer : GuiBase
---@operator call: ItemRenamer
ItemRenamer = GuiBase:extend()

ItemRenamer.DefaultItemNumber = 1
ItemRenamer.RecentSavedMax = 5

ItemRenamer.Error = {
    NO_ITEM_SELECTION = "-- No items selected --",
    NO_AUTHOR = "-- No Project Author set --",
    NO_PROJECT_ON_DISK = "-- Project not saved --",
    NO_REGION = "-- No region for first item --",
    NO_SPECIAL_REGION = "-- No special regions in project --",
    NO_MARKER = "-- No marker for first item --",
    NO_SPECIAL_MARKER = "-- No special marker for first item --",
    NO_FX = "-- No FX for active item --",
    NO_ACTIVE_TAKE = "-- Item missing active take --",
    NO_TAKE_NOTES = "-- Take has no notes --",
    NO_AUDIO_SOURCE = "-- Take is missing audio source --"
}

---@param name string
---@param undoText string
function ItemRenamer:new(name, undoText)
    ItemRenamer.super.new(self, name, undoText)

    self.windowFlags = self.windowFlags + ImGui.WindowFlags_MenuBar

    self.config = Config(FileSys.GetRawName(name))
    self.cfgInfo = {}
    
    self.cfgInfo.repString = "replacementString"
    self.cfgInfo.recent = {}
    for i = 1, ItemRenamer.RecentSavedMax do
        self.cfgInfo.recent[i] = "recent" .. tostring(i)
    end

    local value <const> = self.config:ReadString(self.cfgInfo.repString)
    self:ReadRecent()

    self.items = Project(THIS_PROJECT):GetSelectedItems()
    self.input = value or ""

    self.separatorList = { "-", " ", "_", "+", "=" }

    -- selectors
    self.TrackXSelector = 0
    self.RegionXSelector = 0
    self.MarkerXSelector = 0
    self.FxXSelector = 0

    self.windowWidth = 400
    self.windowHeight = 96
end

function ItemRenamer:ProcessItems()
    local itemNumberOnTrack = 0
    local currentTrack = nil
    for i, item in pairs(self.items) do
        local take <const> = item:GetActiveTake()
        if take == nil then goto continue end

        local newTrack <const> = take:GetTrack()
        assert(newTrack, "All Takes belong to a Track")

        if currentTrack ~= newTrack then
            currentTrack = newTrack
            itemNumberOnTrack = 0
        end

        itemNumberOnTrack = itemNumberOnTrack + 1

        local value = self.input
        value = self:LocalWildcardParseTake(value, i, itemNumberOnTrack)
        value = take:WildcardParse(value)
        take:SetString("P_NAME", value)

        ::continue::
    end
end

---@param value string
---@param itemNumber integer
---@param itemNumberOnTrack integer
---@return string
function ItemRenamer:LocalWildcardParseTake(value, itemNumber, itemNumberOnTrack)
    local itemCount <const> = Project(THIS_PROJECT):CountSelectedItems()

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

            local replacement = Str.IsInt(tag) and
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

---@param tooltip string
---@param info string
---@param selector? integer
function ItemRenamer:DrawMenuItemTooltip(tooltip, info, selector)
    selector = selector or 0
    if ImGui.IsItemHovered(self.ctx) then
        local verticalOut <const> = ImGui.GetMouseWheel(self.ctx);

        if verticalOut > 0 then
            selector = selector + 1
        end
        if verticalOut < 0 then
            selector = selector - 1
        end

        ImGui.SetNextWindowSize(self.ctx, 200.0, 0.0)
        if ImGui.BeginTooltip(self.ctx) then
            local textWrapPos <const> = 0.0 -- 0.0: wrap to end of window (or column)
            ImGui.PushTextWrapPos(self.ctx, textWrapPos)

            ImGui.Text(self.ctx, tooltip .. "\n\n" .. info)
            ImGui.PopTextWrapPos(self.ctx)
            ImGui.EndTooltip(self.ctx)
        end
    end

    return selector
end

---@param wildcard Wildcard
---@param info string
function ItemRenamer:DrawMenuItem(wildcard, info)
    if ImGui.MenuItem(self.ctx, wildcard.tag) then
        self.input = self.input .. wildcard.tag
    end

    self:DrawMenuItemTooltip(wildcard.tooltip, info)
end

---@param wildcard table
---@param info table
---@param selector integer
---@return integer -- selector
function ItemRenamer:DrawSpecialMenuItemString(wildcard, info, selector)
    local specialtag = string.format(wildcard.tag, info.input)
    if ImGui.MenuItem(self.ctx, specialtag) then
        self.input = self.input .. specialtag
    end

    return self:DrawMenuItemTooltip(wildcard.tooltip, info.output, selector)
end

function ItemRenamer:DrawSpecialMenuItemNumber(wildcard, info, selector)
    local specialtag = string.format(wildcard.tag, selector)
    if ImGui.MenuItem(self.ctx, specialtag) then
        self.input = self.input .. specialtag
    end

    return self:DrawMenuItemTooltip(wildcard.tooltip, info, selector)
end

---@return Item?, string
function ItemRenamer:TryGetFirstItem()
    if table.isEmpty(self.items) then return nil, ItemRenamer.Error.NO_ITEM_SELECTION end
    return self.items[1], ""
end

---@param item Item
---@return Take?, string
function ItemRenamer:TryGetFirstTake(item)
    local take <const> = item:GetActiveTake()
    if not take then return nil, ItemRenamer.Error.NO_ACTIVE_TAKE end
    return take, ""
end

function ItemRenamer:PrintProjectName()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    local value <const> = take:WildcardParse(Wildcards.PROJECT.tag)
    return Str.IsNilOrEmpty(value) and ItemRenamer.Error.NO_PROJECT_ON_DISK or value
end

function ItemRenamer:PrintAuthorName()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    local value <const> = take:WildcardParse(Wildcards.AUTHOR.tag)
    return Str.IsNilOrEmpty(value) and ItemRenamer.Error.NO_AUTHOR or value
end

function ItemRenamer:PrintItemNotes()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    local value <const> = take:WildcardParse(Wildcards.ITEMNOTES.tag)
    return Str.IsNilOrEmpty(value) and ItemRenamer.Error.NO_TAKE_NOTES or value
end

function ItemRenamer:PrintRegion()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    local value <const> = take:WildcardParse(Wildcards.REGION.tag)
    return Str.IsNilOrEmpty(value) and ItemRenamer.Error.NO_REGION or value
end

function ItemRenamer:PrintMarker()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    local value <const> = take:WildcardParse(Wildcards.MARKER.tag)
    return Str.IsNilOrEmpty(value) and ItemRenamer.Error.NO_MARKER or value
end

function ItemRenamer:PrintTakeFx()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    local value <const> = take:WildcardParse(Wildcards.FX.tag)
    return Str.IsNilOrEmpty(value) and ItemRenamer.Error.NO_FX or value
end

function ItemRenamer:PrintTag(wildcard)
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    return take:WildcardParse(wildcard.tag)
end

function ItemRenamer:PrintFirstItemNumber()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    return "1" -- #doesn't change if more than 1 item
end

function ItemRenamer:PrintLUFS()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    local source <const> = take:GetSource()
    if source == nil or not source:IsValid() then return ItemRenamer.Error.NO_AUDIO_SOURCE end
    return take:WildcardParse(Wildcards.LUFS.tag)
end

function ItemRenamer:PrintPeak()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    local source <const> = take:GetSource()
    if source == nil or not source:IsValid() then return ItemRenamer.Error.NO_AUDIO_SOURCE end
    return take:WildcardParse(Wildcards.PEAK.tag)
end

function ItemRenamer:PrintRMS()
    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end
    local source <const> = take:GetSource()
    if source == nil or not source:IsValid() then return ItemRenamer.Error.NO_AUDIO_SOURCE end
    return take:WildcardParse(Wildcards.RMS.tag)
end

function ItemRenamer:PrintTrackX()
    self.TrackXSelector = Maths.Clamp(self.TrackXSelector, 0, Maths.Int32Max)

    local item <const>, itemError = self:TryGetFirstItem()
    if not item then return itemError end
    local take <const>, takeError = self:TryGetFirstTake(item)
    if not take then return takeError end

    return take:WildcardParse(string.format(Wildcards.TRACKX.tag, self.TrackXSelector))
end

function ItemRenamer:PrintRegionX()
    if table.isEmpty(self.items) then return { input = "", output = ItemRenamer.Error.NO_ITEM_SELECTION } end
    local specialRegions <const> = Project():GetSpecialRegions()

    if (table.isEmpty(specialRegions)) then return { input = "", output = ItemRenamer.Error.NO_SPECIAL_REGION } end

    local uniqueRegions = {}
    for _, specialRegion in pairs(specialRegions) do
        local contains = false
        for _, uniqueRegion in pairs(uniqueRegions) do
            if specialRegion.name:sub(1, specialRegion.name:find("=")) == uniqueRegion.name:sub(1, uniqueRegion.name:find("=")) then
                contains = true
                break
            end
        end
        if not contains then
            table.insert(uniqueRegions, specialRegion)
        end
    end

    self.RegionXSelector = Maths.Clamp(self.RegionXSelector, 1, #uniqueRegions);

    local regionName <const> = uniqueRegions[self.RegionXSelector].name
    local equalsPos <const> = string.find(regionName, "=");
    local regionPreEquals <const> = string.sub(regionName, 0, equalsPos - 1)

    return
    {
        input = regionPreEquals,
        output = reaper.GU_WildcardParseTake(self.items[1]:GetActiveTake().id,
            string.format(Wildcards.REGIONX.tag, regionPreEquals))
    }
end

function ItemRenamer:PrintMarkerX()
    if table.isEmpty(self.items) then return { input = "", output = ItemRenamer.Error.NO_ITEM_SELECTION } end
    local specialMarkers <const> = Project():GetSpecialMarkers()

    if (table.isEmpty(specialMarkers)) then return { input = "", output = ItemRenamer.Error.NO_SPECIAL_MARKER } end

    local uniqueMarkers = {}
    for _, specialMarker in pairs(specialMarkers) do
        local contains = false
        for _, uniqueMarker in pairs(uniqueMarkers) do
            if specialMarker.name:sub(1, specialMarker.name:find("=")) == uniqueMarker.name:sub(1, uniqueMarker.name:find("=")) then
                contains = true
                break
            end
        end
        if not contains then
            table.insert(uniqueMarkers, specialMarker)
        end
    end

    self.MarkerXSelector = Maths.Clamp(self.MarkerXSelector, 1, #uniqueMarkers)

    local markerName <const> = uniqueMarkers[self.MarkerXSelector].name
    local equalsPos <const> = string.find(markerName, "=");
    local markerPreEquals <const> = string.sub(markerName, 0, equalsPos - 1)

    return
    {
        input = markerPreEquals,
        output = reaper.GU_WildcardParseTake(self.items[1]:GetActiveTake().id,
            string.format(Wildcards.MARKERX.tag, markerPreEquals))
    }
end

---@return table
function ItemRenamer:PrintTakeFxX()
    if table.isEmpty(self.items) then return { input = "", output = ItemRenamer.Error.NO_ITEM_SELECTION } end
    if self.items[1]:GetActiveTake().id == nil then return { input = "", output = ItemRenamer.Error.NO_ACTIVE_TAKE } end

    if self.FxXSelector < 1 then self.FxXSelector = #self.separatorList end
    if self.FxXSelector > #self.separatorList then self.FxXSelector = 1 end

    local separator <const> = self.separatorList[self.FxXSelector]

    local fxList <const> = reaper.GU_WildcardParseTake(self.items[1]:GetActiveTake().id,
        string.format(Wildcards.FXX.tag, separator))

    if (Str.IsNilOrEmpty(fxList)) then return { input = "", output = ItemRenamer.Error.NO_FX } end
    return { input = separator, output = fxList }
end

function ItemRenamer:DrawMenu()
    if ImGui.BeginMenuBar(self.ctx) then
        if ImGui.BeginMenu(self.ctx, "File") then
            if ImGui.BeginMenu(self.ctx, "Recent") then
                for i = 1, ItemRenamer.RecentSavedMax do
                    if ImGui.MenuItem(self.ctx, ("%d: %s"):format(i, self.recent[i])) then
                        self.input = self.recent[i]
                    end
                end
                ImGui.EndMenu(self.ctx)
            end
            ImGui.EndMenu(self.ctx)
        end
        if ImGui.BeginMenu(self.ctx, "Wildcards") then
            if ImGui.BeginMenu(self.ctx, "Project Information") then
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
                self.MarkerXSelector = self:DrawSpecialMenuItemString(Wildcards.MARKERX, self:PrintMarkerX(),
                    self.MarkerXSelector)
                self:DrawMenuItem(Wildcards.MARKER, self:PrintMarker())
                self:DrawMenuItem(Wildcards.TEMPO, self:PrintTag(Wildcards.TEMPO))
                self:DrawMenuItem(Wildcards.TIMESIG, self:PrintTag(Wildcards.TIMESIG))
                self.FxXSelector = self:DrawSpecialMenuItemString(Wildcards.FXX, self:PrintTakeFxX(),
                    self.FxXSelector)
                self:DrawMenuItem(Wildcards.FX, self:PrintTakeFx())
                ImGui.EndMenu(self.ctx)
            end
            if ImGui.BeginMenu(self.ctx, "Project Order") then
                self:DrawMenuItem(Wildcards.ITEMCOUNT, self:PrintTag(Wildcards.ITEMCOUNT))
                self:DrawMenuItem(Wildcards.ITEMNUMBER, self:PrintFirstItemNumber())
                self:DrawMenuItem(Wildcards.ITEMNUMBERONTRACK, self:PrintFirstItemNumber())
                ImGui.EndMenu(self.ctx)
            end
            if ImGui.BeginMenu(self.ctx, "Media Item Information") then
                self:DrawMenuItem(Wildcards.ITEM, self:PrintTag(Wildcards.ITEM))
                self:DrawMenuItem(Wildcards.ITEMNOTES, self:PrintItemNotes())
                ImGui.EndMenu(self.ctx)
            end
            if ImGui.BeginMenu(self.ctx, "Date/Time") then
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
                ImGui.EndMenu(self.ctx);
            end
            if ImGui.BeginMenu(self.ctx, "Metering") then
                self:DrawMenuItem(Wildcards.LUFS, self:PrintLUFS()) -- todo give example only, don't do real-time
                self:DrawMenuItem(Wildcards.PEAK, self:PrintPeak()) -- todo give example only, don't do real-time
                self:DrawMenuItem(Wildcards.RMS, self:PrintRMS()) -- todo give example only, don't do real-time
                ImGui.EndMenu(self.ctx)
            end
            ImGui.EndMenu(self.ctx);
        end
        ImGui.EndMenuBar(self.ctx);
    end
end

function ItemRenamer:ReadRecent()
    self.recent = {}
    for i = 1, ItemRenamer.RecentSavedMax do
        self.recent[i] = self.config:ReadString(self.cfgInfo.recent[i])
    end
end

function ItemRenamer:SaveRecent()
    self.config:Write(self.cfgInfo.repString, self.input)

    if self.config:ReadString(self.cfgInfo.recent[1]) == self.input then return end -- Don't store recent if its already there

    for i = ItemRenamer.RecentSavedMax, 2, -1 do
        local temp <const> = self.config:ReadString(self.cfgInfo.recent[i - 1])
        if not temp then goto continue end
        self.config:Write(self.cfgInfo.recent[i], temp)
        ::continue::
    end

    self.config:Write(self.cfgInfo.recent[1], self.input)

    self:ReadRecent()
end

function ItemRenamer:Frame()
    local latestState <const> = reaper.GetProjectStateChangeCount(THIS_PROJECT)
    if self.lastProjectState ~= latestState then
        self.lastProjectState = latestState
        self.items = Project(THIS_PROJECT):GetSelectedItems()
    end

    self:DrawMenu()

    if self.frameCounter == 1 then
        ImGui.SetKeyboardFocusHere(self.ctx)
    end

    ImGui.PushItemWidth(self.ctx, -1);
    _, self.input = ImGui.InputText(self.ctx, " ", self.input)
    ImGui.PopItemWidth(self.ctx)

    if ImGui.Button(self.ctx, "Apply") or ImGuiExt.IsEnterKeyPressed(self.ctx) then
        self:Begin()
        self:ProcessItems()
        self:SaveRecent()
        self:Complete(4)
    end
end

local scriptPath <const> = debug.getinfo(1).source

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = ItemRenamer(file, "Rename selected items")

reaper.defer(function () gui:Loop() end)
