-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('Lua.gutil_classic')
require('Lua.gutil_color')
require('Lua.gutil_table')
require('Lua.gutil_filesystem')
require('Reaper.gutil_config')
require('Reaper.gutil_gui')
require('Reaper.gutil_item')
require('Reaper.gutil_project')
require('Reaper.gutil_source')
require('Reaper.gutil_progressbar')
require('Reaper.gutil_take')
require('Reaper.gutil_track')

---@class (exact) ValidatorData : Object
---@operator call : ValidatorData
---@field selected boolean
---@field path string
---@field index integer
---@field name string
---@field fileFormat string
---@field channelCount integer
---@field length number
---@field sampleRate integer
---@field bitDepth integer
---@field peak number
---@field loudness number
---@field silenceIn number
---@field silenceOut number
---@field isZeroStart boolean
---@field isZeroEnd boolean
---@field hasRegion boolean
---@field isMono boolean
ValidatorData = Object:extend()

---@alias SilenceDetectionAlgorithm
---| 0 # Peak
---| 1 # RMS

function ValidatorData:__eq(other)
    return other:is(ValidatorData) and self.path == other.path
end

---@class ValidatorProperty : Object
ValidatorProperty = Object:extend()

ValidatorProperty.Type = {
    Index = 0,
    Name = 1,
    FileFormat = 2,
    Channels = 3,
    Length = 4,
    SampleRate = 5,
    BitDepth = 6,
    Peak = 7,
    Loudness = 8,
    SilenceIn = 9,
    SilenceOut = 10,
    ZeroStart = 11,
    ZeroEnd = 12,
    HasRegion = 13,
    IsMono = 14,
}

ValidatorProperty.ExportStrings = {
    "index",
    "name",
    "fileFormat",
    "channelCount",
    "length",
    "sampleRate",
    "bitDepth",
    "peak",
    "loudness",
    "silenceIn",
    "silenceOut",
    "isZeroStart",
    "isZeroEnd",
    "hasRegion",
    "isMono"
}

function ValidatorProperty:new(title, abbreviation, cfgName, toolTip)
    self.shouldCheck = false
    self.title = title
    self.abbreviation = abbreviation
    self.cfgName = cfgName
    self.toolTip = toolTip
end

local vp <const> = ValidatorProperty

---@class SrcValidator : Object
---@operator call: SrcValidator
---@field detectionAlgorithm SilenceDetectionAlgorithm
SrcValidator = Object:extend()

function SrcValidator:new()
    self.data = {}
    self.project = Project(THIS_PROJECT) ---@type Project
    self.items = {} ---@type Item[]

    self.prog = {}
    self.prog.gui = nil ---@type ProgressBar?
    self.prog.num = 0
    self.prog.denom = 0

    return self
end

function SrcValidator:FillItemsFromProject()
    table.clear(self.data)
    self.items = self.project:GetAllItems()
    self.prog.gui = nil
end

function SrcValidator:FillItemsFromSelection()
    table.clear(self.data)
    self.items = self.project:GetSelectedItems()
    self.prog.gui = nil
end

function SrcValidator:TryFillDataSync()
    local input <const> = Dialog.MB("Reaper will appear unresponsive while your items are processed.\nDo you want to continue?", "Warning", 4)
    if input == 7 then
        table.clear(self.items)
    end

    if table.isEmpty(self.items) then return end

    while not table.isEmpty(self.items) do
        self:FillData()
    end
end

function SrcValidator:TryFillDataAsync()
    if table.isEmpty(self.items) then
        self.prog.gui = nil
        return
    end

    if self.prog.gui == nil then
        self:InitProgressBar(#self.items)
    end

    if self.prog.gui ~= nil then
        if self.prog.gui.fraction ~= nil and self.prog.gui.fraction >= 1 then
            self.prog.gui = nil
        elseif not ImGui.ValidatePtr(self.prog.gui.ctx, "ImGui_Context*") then
            self.prog.gui = nil
        else
            reaper.defer(function () self:FillData() end)
        end
    end
end

---@param count integer --- number to iterate over
function SrcValidator:InitProgressBar(count)
    self.prog.num = 0
    self.prog.denom = count
    self.prog.gui = ProgressBar("progress bar")
    self.prog.gui:Loop()
end

function SrcValidator:FillData()
    self.prog.num = self.prog.num + 1

    if self.prog.gui ~= nil then
        assert(self.prog.denom ~= nil and self.prog.denom > 0)
        self.prog.gui.fraction = self.prog.num / self.prog.denom
    end

    if not table.isEmpty(self.items) then
        local item <const> = self.items[1] ---@type Item
        --assert(item, "table is not empty, but getting nil item")
        if not item then goto removeItem end

        local take <const> = item:GetActiveTake()
        if not take then goto removeItem end

        local source <const> = take:GetSource()
        if not source or not source:IsValid() then goto removeItem end

        local data <const> = ValidatorData()
        data.path = source:GetPath()

        -- don't process duplicate source data
        for _, v in pairs(self.data) do
            if v.path == data.path then
                goto removeItem
            end
        end

        data.index = #self.data
        data.name = select(2, FileSys.Path.Parse(data.path))
        data.fileFormat = select(3, FileSys.Path.Parse(data.path))
        data.channelCount = source:GetChannelCount()
        data.length = source:GetLength()
        data.sampleRate = source:GetSampleRate()
        data.bitDepth = source:GetBitDepth()
        data.peak = source:GetPeak()
        data.loudness = source:GetLUFS()
        data.silenceIn = self.detectionAlgorithm == 0 and
            source:GetTimeToPeak(self.bufferSize, self.silenceThreshold) or
            source:GetTimeToRMS(self.bufferSize, self.silenceThreshold)
        data.silenceOut = self.detectionAlgorithm == 0 and
            source:GetTimeToPeakR(self.bufferSize, self.silenceThreshold) or
            source:GetTimeToRMSR(self.bufferSize, self.silenceThreshold)
        data.isZeroStart = source:IsFirstSampleZero(Maths.DB2VOL(self.silenceThreshold))
        data.isZeroEnd = source:IsLastSampleZero(Maths.DB2VOL(self.silenceThreshold))
        data.hasRegion = source:HasLoopMarker()
        data.isMono = source:IsMono()

        table.insert(self.data, data)
    end

    ::removeItem::

    table.remove(self.items, 1)

    if self.prog.gui ~= nil and self.prog.gui.shouldTerminate then
        table.clear(self.items)
    end
end

function SrcValidator:UpdateSettings(algorithm, threshold, bufferSize)
    self.detectionAlgorithm = algorithm
    self.silenceThreshold = threshold
    self.bufferSize = bufferSize
end

---@class AudioFormatSelection
AudioFormatSelection = Object:extend()

function AudioFormatSelection:new(name)
    self.isSelected = false
    self.name = name

    return self
end

---@class GuiSrcValidator : GuiBase
GuiSrcValidator = GuiBase:extend()

GuiSrcValidator.Properties = {}

table.insert(GuiSrcValidator.Properties,
    vp("Index", "ID", "index", ""))
table.insert(GuiSrcValidator.Properties,
    vp("Name", "NM", "name", "Name of file on disk"))
table.insert(GuiSrcValidator.Properties,
    vp("File Format", "FF", "file_format", "Audio file format (supports WAV, AIFF, FLAC, MP3, OGG, and BWF)"))
table.insert(GuiSrcValidator.Properties,
    vp("Channels", "CH", "channels", ""))
table.insert(GuiSrcValidator.Properties,
    vp("Length", "LN", "length", ""))
table.insert(GuiSrcValidator.Properties,
    vp("Sample Rate", "SR", "sample_rate", ""))
table.insert(GuiSrcValidator.Properties,
    vp("Bit Depth", "BD", "bit_depth", ""))
table.insert(GuiSrcValidator.Properties,
    vp("Peak", "PK", "peak", "Peak amplitude"))
table.insert(GuiSrcValidator.Properties,
    vp("Loudness", "LD", "loudness", "Integrated LUFS"))
table.insert(GuiSrcValidator.Properties,
    vp("Silence Intro", "SI", "silence_intro", "Silence in seconds as defined in Settings -> Detection"))
table.insert(GuiSrcValidator.Properties,
    vp("Silence Outro", "SO", "silence_outro", "Silence in seconds as defined in Settings -> Detection"))
table.insert(GuiSrcValidator.Properties,
    vp("Zero Start", "ZXI", "zero_start", "'o' if first sample is -inf dB"))
table.insert(GuiSrcValidator.Properties,
    vp("Zero End", "ZXO", "zero_end", "'o' if last sample is -inf dB"))
table.insert(GuiSrcValidator.Properties,
    vp("Regions", "RGN", "has_region", "'o' if region/loop is embedded"))
table.insert(GuiSrcValidator.Properties,
    vp("IsMono", "MON", "is_mono", "'o' if all channels are identical"))

GuiSrcValidator.AudioFormatSelections = {}

for _, name in pairs(reaper.AudioFormats) do
    table.insert(GuiSrcValidator.AudioFormatSelections, AudioFormatSelection(name))
end

---@alias relation "<" | ">"

---@param name string
---@param undoText string
---@param isAsync boolean
function GuiSrcValidator:new(name, undoText, isAsync)
    GuiSrcValidator.super.new(self, name, undoText)

    self.validator = SrcValidator()
    self.isAsync = isAsync

    -- config
    self.config = Config(FileSys.GetRawName(name)) ---@type Config

    self.cfgInfo = {}
    self.cfgInfo.csvPath = "csvPath"
    self.cfgInfo.radioFlags = "radioFlags"
    self.cfgInfo.shortTitles = "shortTitles"
    self.cfgInfo.algorithm = "algorithm"
    self.cfgInfo.bufferSize = "bufferSize"
    self.cfgInfo.threshold = "threshold"
    self.cfgInfo.rgb = "rgb"
    self.cfgInfo.fileFormat = "fileFormat"
    self.cfgInfo.channels = "channels"
    self.cfgInfo.length = "length"
    self.cfgInfo.sampleRate = "sampleRate"
    self.cfgInfo.bitDepth = "bitDepth"
    self.cfgInfo.peak = "peak"
    self.cfgInfo.loudness = "loudness"
    self.cfgInfo.silenceIn = "silenceIn"
    self.cfgInfo.silenceOut = "silenceOut"
    self.cfgInfo.conditional = "conditional"
    self.cfgInfo.shouldCheck = "shouldCheck"

    self.isShortTitles = self.config:ReadBool(self.cfgInfo.shortTitles) or false
    self.radioFlags = self.config:ReadNumber(self.cfgInfo.radioFlags) or 1
    self.tableFlags = GuiSrcValidator.TableFlag[self.radioFlags][2]
    self.threshold = self.config:ReadNumber(self.cfgInfo.threshold) or -144.0
    self.detectionAlgorithm = self.config:ReadNumber(self.cfgInfo.algorithm) or 0
    self.bufferSize = toint(self.config:ReadNumber(self.cfgInfo.bufferSize) or 32)
    self.popUp = "Deviations" -- used as an id to keep track of popup

    GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck =
        self.config:ReadBool(self.cfgInfo.fileFormat .. self.cfgInfo.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck =
        self.config:ReadBool(self.cfgInfo.channels .. self.cfgInfo.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck =
        self.config:ReadBool(self.cfgInfo.length .. self.cfgInfo.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck =
        self.config:ReadBool(self.cfgInfo.sampleRate .. self.cfgInfo.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck =
        self.config:ReadBool(self.cfgInfo.bitDepth .. self.cfgInfo.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck =
        self.config:ReadBool(self.cfgInfo.peak .. self.cfgInfo.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck =
        self.config:ReadBool(self.cfgInfo.loudness .. self.cfgInfo.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck =
        self.config:ReadBool(self.cfgInfo.silenceIn .. self.cfgInfo.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck =
        self.config:ReadBool(self.cfgInfo.silenceOut .. self.cfgInfo.shouldCheck)

    self.currentFileFormat = self.config:ReadString(self.cfgInfo.fileFormat) or reaper.AudioFormats[1]
    self.currentChannels = toint(self.config:ReadNumber(self.cfgInfo.channels) or 2)
    self.currentLength = self.config:ReadNumber(self.cfgInfo.length) or 0
    self.currentLengthRelationCombo = self.config:ReadString(self.cfgInfo.length .. self.cfgInfo.conditional) or '<'
    self.currentSampleRate = toint(self.config:ReadNumber(self.cfgInfo.sampleRate) or 44100)
    self.currentBitDepth = toint(self.config:ReadNumber(self.cfgInfo.bitDepth) or 24)
    self.currentPeak = self.config:ReadNumber(self.cfgInfo.peak) or 0
    self.currentPeakRelationCombo = self.config:ReadString(self.cfgInfo.peak .. self.cfgInfo.conditional) or '<'
    self.currentLoudness = self.config:ReadNumber(self.cfgInfo.loudness) or 0
    self.currentLoudnessRelationCombo = self.config:ReadString(self.cfgInfo.loudness .. self.cfgInfo.conditional) or '<'
    self.currentSilenceIn = self.config:ReadNumber(self.cfgInfo.silenceIn) or 0
    self.currentSilenceOut = self.config:ReadNumber(self.cfgInfo.silenceOut) or 0

    -- colors
    local colors <const> = Color.GetColorTable(self.config:ReadNumber(self.cfgInfo.rgb))
    self.curR = colors.red or 255
    self.curB = colors.blue or 0
    self.curG = colors.green or 0

    -- gui
    self.windowWidth = 1280
    self.windowHeight = 720
    self.windowFlags = self.windowFlags + ImGui.WindowFlags_MenuBar
    self.relationalComboWidth = self.font.size * 2 + 10

    return self
end

function GuiSrcValidator:CreateCSVFileName()
    local time <const> = os.date("*t")
    -- todo check this
    local projectName = "SourceValidator_" .. reaper.GetProjectName(THIS_PROJECT)
    if not Str.IsNilOrEmpty(projectName) then
        projectName = projectName .. "_"
    end
    return projectName ..
        time.year .. "_" .. time.month .. "_" .. time.day .. "_" .. time.hour .. "_" .. time.min .. "_" .. time.sec .. ".csv"
end

function GuiSrcValidator:CurrentColor()
    return Color.CreateRGBA(self.curR, self.curG, self.curB)
end

function GuiSrcValidator:AsyncFrame()
    -- todo: check state change
    if ImGui.BeginMenuBar(self.ctx) then
        if ImGui.BeginMenu(self.ctx, "File") then
            if ImGui.MenuItem(self.ctx, "Copy") then
                self:CopyToClipboard();
            end

            if ImGui.MenuItem(self.ctx, "Export CSV...") then
                self:PrintToCSV();
            end

            ImGui.EndMenu(self.ctx)
        end

        if ImGui.BeginMenu(self.ctx, "Settings") then
            self:Menu_TableView();
            self:Menu_Detection();
            self:Menu_ColorSelector();
            _, self.isShortTitles = ImGui.Checkbox(self.ctx, "Use Short Titles", self.isShortTitles);

            ImGui.EndMenu(self.ctx);
        end
        ImGui.EndMenuBar(self.ctx)
    end

    if ImGui.Button(self.ctx, "Check All Items") then
        self.validator:UpdateSettings(self.detectionAlgorithm, self.threshold, self.bufferSize)
        self.validator:FillItemsFromProject()
    end

    ImGui.SameLine(self.ctx)

    if ImGui.Button(self.ctx, "Check Selected Items") then
        self.validator:UpdateSettings(self.detectionAlgorithm, self.threshold, self.bufferSize)
        self.validator:FillItemsFromSelection()
    end

    ImGui.SameLine(self.ctx)

    if ImGui.Button(self.ctx, "Set Validation Settings") then
        ImGui.OpenPopup(self.ctx, self.popUp)
    end

    if ImGui.BeginPopup(self.ctx, self.popUp) then
        local offsetA <const> = self.font.size * 10
        local offsetB <const> = offsetA + self.relationalComboWidth + 4

        ImGui.Text(self.ctx, "Validation Toggle")
        ImGui.Separator(self.ctx)

        self:DrawCheck_FileFormat(offsetB);
        self:DrawCheck_ChannelCount(offsetB);
        self:DrawCheck_Length(offsetA, offsetB);
        self:DrawCheck_SampleRate(offsetB);
        self:DrawCheck_BitDepth(offsetB);
        self:DrawCheck_Peak(offsetA, offsetB);
        self:DrawCheck_Loudness(offsetA, offsetB);
        self:DrawCheck_SilenceForward(offsetB);
        self:DrawCheck_SilenceBackward(offsetB);

        ImGui.EndPopup(self.ctx)
    end

    self.validator:TryFillDataAsync()

    if ImGui.BeginTable(self.ctx, "Items", #GuiSrcValidator.Properties, self.tableFlags) then
        ImGuiExt.TableNext(self.ctx)
        for _, property in pairs(GuiSrcValidator.Properties) do
            ImGuiExt.TableHeading(self.ctx, self.isShortTitles and property.abbreviation or property.title)

            if ImGui.IsItemHovered(self.ctx) then
                if ImGui.BeginTooltip(self.ctx) then
                    ImGui.Text(self.ctx, property.toolTip)
                    ImGui.EndTooltip(self.ctx)
                end
            end
        end

        for _, data in pairs(self.validator.data) do
            ImGuiExt.TableNext(self.ctx)
            ImGui.Text(self.ctx, tostring(data.index)); -- index

            self:DrawTable_Name(data.name);
            self:DrawTable_FileFormat(data.fileFormat);
            self:DrawTable_ChannelCount(data.channelCount);
            self:DrawTable_Length(data.length);
            self:DrawTable_SampleRate(data.sampleRate);
            self:DrawTable_BitDepth(data.bitDepth);
            self:DrawTable_Peak(data.peak);
            self:DrawTable_Loudness(data.loudness);
            self:DrawTable_SilenceForward(data.silenceIn);
            self:DrawTable_SilenceBackward(data.silenceOut);
            self:DrawTable_IsZeroStart(data.isZeroStart);
            self:DrawTable_IsZeroEnd(data.isZeroEnd);
            self:DrawTable_HasRegion(data.hasRegion);
            self:DrawTable_IsMono(data.isMono);
        end

        ImGui.EndTable(self.ctx)
    end
end

function GuiSrcValidator:SyncFrame()
    Debug.Log("Processing, please wait...\n")
    self.validator:UpdateSettings(self.detectionAlgorithm, self.threshold, self.bufferSize)
    self.validator:FillItemsFromProject()
    self.validator:TryFillDataSync()
    if not table.isEmpty(self.validator.data) then
        self:PrintToCSV()
    end
    Debug.Log("Final source media items processed: %i\n", #self.validator.data)
    self:Close()
end

function GuiSrcValidator:Frame()
    if self.isAsync then
        self:AsyncFrame()
    else
        self:SyncFrame()
    end
end

function GuiSrcValidator:DrawTable_Name(name)
    ImGuiExt.TableNextColumnEntry(self.ctx, name, Color.White)
end

function GuiSrcValidator:DrawTable_FileFormat(fileFormat)
    fileFormat = string.upper(fileFormat)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck and fileFormat ~= self.currentFileFormat) and
        self:CurrentColor() or Color.White
    ImGuiExt.TableNextColumnEntry(self.ctx, string.format("%s", fileFormat), col)
end

function GuiSrcValidator:DrawTable_ChannelCount(channelCount)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck and channelCount ~= self.currentChannels) and
        self:CurrentColor() or Color.White
    ImGuiExt.TableNextColumnEntry(self.ctx, channelCount, col)
end

function GuiSrcValidator:DrawTable_Length(length)
    local col = 0
    if self.currentLengthRelationCombo == '<' then
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck and length >= self.currentLength) and
            self:CurrentColor() or Color.White
    else
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck and length <= self.currentLength) and
            self:CurrentColor() or Color.White
    end
    ImGuiExt.TableNextColumnEntry(self.ctx, string.format("%.3f s", length), col)
end

function GuiSrcValidator:DrawTable_SampleRate(sampleRate)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck and sampleRate ~= self.currentSampleRate) and
        self:CurrentColor() or Color.White
    ImGuiExt.TableNextColumnEntry(self.ctx, string.format("%.1f kHz", sampleRate / 1000), col)
end

function GuiSrcValidator:DrawTable_BitDepth(bitDepth)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck and bitDepth ~= self.currentBitDepth) and
        self:CurrentColor() or Color.White
    ImGuiExt.TableNextColumnEntry(self.ctx, bitDepth, col)
end

function GuiSrcValidator:DrawTable_Peak(peak)
    local col = 0
    if self.currentPeakRelationCombo == '<' then
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck and peak >= self.currentPeak) and
            self:CurrentColor() or Color.White
    else
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck and peak <= self.currentPeak) and
            self:CurrentColor() or Color.White
    end
    ImGuiExt.TableNextColumnEntry(self.ctx, string.format("%.1f", peak), col)
end

function GuiSrcValidator:DrawTable_Loudness(loudness)
    local col = 0
    if self.currentLoudnessRelationCombo == '<' then
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck and loudness >= self.currentLoudness) and
            self:CurrentColor() or Color.White
    else
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck and loudness <= self.currentLoudness) and
            self:CurrentColor() or Color.White
    end
    ImGuiExt.TableNextColumnEntry(self.ctx, string.format("%.1f", loudness), col)
end

function GuiSrcValidator:DrawTable_SilenceForward(silenceIn)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck and silenceIn < self.currentSilenceIn) and
        self:CurrentColor() or Color.White
    ImGuiExt.TableNextColumnEntry(self.ctx, string.format("%.3f s", silenceIn), col)
end

function GuiSrcValidator:DrawTable_SilenceBackward(silenceOut)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck and silenceOut < self.currentSilenceOut) and
        self:CurrentColor() or Color.White
    ImGuiExt.TableNextColumnEntry(self.ctx, string.format("%.3f s", silenceOut), col)
end

function GuiSrcValidator:DrawTable_IsZeroStart(isZeroStart)
    ImGuiExt.TableNextColumnEntry(self.ctx, isZeroStart and "o" or "x", Color.White)
end

function GuiSrcValidator:DrawTable_IsZeroEnd(isZeroEnd)
    ImGuiExt.TableNextColumnEntry(self.ctx, isZeroEnd and "o" or "x", Color.White)
end

function GuiSrcValidator:DrawTable_HasRegion(hasRegion)
    ImGuiExt.TableNextColumnEntry(self.ctx, hasRegion and "o" or "x", Color.White)
end

function GuiSrcValidator:DrawTable_IsMono(isMono)
    ImGuiExt.TableNextColumnEntry(self.ctx, isMono and "o" or "x", Color.White)
end

function GuiSrcValidator:DrawCheck_FileFormat(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck =
        ImGui.Checkbox(self.ctx, "File Format",
            GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck);
    ImGui.SameLine(self.ctx, offset);
    self:FileFormatCombo();
end

function GuiSrcValidator:FileFormatCombo()
    if ImGui.BeginCombo(self.ctx, "##CurFileFormat", self.currentFileFormat) then
        for _, data in pairs(GuiSrcValidator.AudioFormatSelections) do
            if ImGui.Selectable(self.ctx, data.name, data.isSelected) then
                self.currentFileFormat = data.name;
            end
        end
        ImGui.EndCombo(self.ctx);
    end
end

function GuiSrcValidator:DrawCheck_ChannelCount(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck =
        ImGui.Checkbox(self.ctx, "Channels",
            GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck)

    ImGui.SameLine(self.ctx, offset);

    _, self.currentChannels =
        ImGui.InputInt(self.ctx, "##CurChannels", self.currentChannels)
end

---comment
---@param label string
---@param relationSelection relation The current relation
---@param relationPotential relation[] The list of supported relations
---@return relation
function GuiSrcValidator:RelationalCombo(label, relationSelection, relationPotential)
    ImGui.PushItemWidth(self.ctx, self.relationalComboWidth)
    local ret = relationSelection
    if ImGui.BeginCombo(self.ctx, label, relationSelection) then
        for _, type in pairs(relationPotential) do
            local retval <const>, _ = ImGui.Selectable(self.ctx, type, false)
            if retval then
                ret = type
            end
        end
        ImGui.EndCombo(self.ctx)
    end
    ImGui.PopItemWidth(self.ctx)
    return ret
end

function GuiSrcValidator:DrawCheck_Length(offsetA, offsetB)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck =
        ImGui.Checkbox(self.ctx, "Length",
            GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck)

    ImGui.SameLine(self.ctx, offsetA)
    self.currentLengthRelationCombo =
        self:RelationalCombo("##RelationalLength", self.currentLengthRelationCombo, { "<", ">" });
    ImGui.SameLine(self.ctx, offsetB)

    _, self.currentLength =
        ImGui.InputDouble(self.ctx, "##CurLength", self.currentLength)
end

function GuiSrcValidator:DrawCheck_SampleRate(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck =
        ImGui.Checkbox(self.ctx, "Sample Rate",
            GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck)

    ImGui.SameLine(self.ctx, offset)

    _, self.currentSampleRate =
        ImGui.InputInt(self.ctx, "##CurSampleRate", self.currentSampleRate)
end

function GuiSrcValidator:DrawCheck_BitDepth(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck =
        ImGui.Checkbox(self.ctx, "Bit Depth",
            GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck)

    ImGui.SameLine(self.ctx, offset)

    _, self.currentBitDepth =
        ImGui.InputInt(self.ctx, "##CurBitDepth", self.currentBitDepth);
end

function GuiSrcValidator:DrawCheck_Peak(offsetA, offsetB)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck =
        ImGui.Checkbox(self.ctx, "Peak",
            GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck)

    ImGui.SameLine(self.ctx, offsetA)
    self.currentPeakRelationCombo =
        self:RelationalCombo("##RelationalPeak", self.currentPeakRelationCombo, { '<', '>' });
    ImGui.SameLine(self.ctx, offsetB)

    _, self.currentPeak =
        ImGui.InputDouble(self.ctx, "##CurPeak", self.currentPeak);
end

function GuiSrcValidator:DrawCheck_Loudness(offsetA, offsetB)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck =
        ImGui.Checkbox(self.ctx, "Loudness",
            GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck)

    ImGui.SameLine(self.ctx, offsetA)
    self.currentLoudnessRelationCombo =
        self:RelationalCombo("##RelationalLoudness", self.currentLoudnessRelationCombo, { '<', '>' });
    ImGui.SameLine(self.ctx, offsetB)

    _, self.currentLoudness =
        ImGui.InputDouble(self.ctx, "##CurLoudness", self.currentLoudness);
end

function GuiSrcValidator:DrawCheck_SilenceForward(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck =
        ImGui.Checkbox(self.ctx, "Silence In",
            GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck)

    ImGui.SameLine(self.ctx, offset);

    _, self.currentSilenceIn =
        ImGui.InputDouble(self.ctx, "##CurSilenceIn", self.currentSilenceIn);
end

function GuiSrcValidator:DrawCheck_SilenceBackward(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck =
        ImGui.Checkbox(self.ctx, "Silence Out",
            GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck)

    ImGui.SameLine(self.ctx, offset);

    _, self.currentSilenceOut =
        ImGui.InputDouble(self.ctx, "##CurSilenceOut", self.currentSilenceOut);
end

function GuiSrcValidator:OnClose()
    self.config:Write(self.cfgInfo.shortTitles, self.isShortTitles)
    self.config:Write(self.cfgInfo.threshold, self.threshold)
    self.config:Write(self.cfgInfo.radioFlags, self.radioFlags)
    self.config:Write(self.cfgInfo.algorithm, self.detectionAlgorithm)
    self.config:Write(self.cfgInfo.bufferSize, self.bufferSize)
    self.config:Write(self.cfgInfo.rgb, Color.CreateRGBA(self.curR, self.curG, self.curB))

    self.config:Write(self.cfgInfo.fileFormat .. self.cfgInfo.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck)
    self.config:Write(self.cfgInfo.fileFormat, self.currentFileFormat)

    self.config:Write(self.cfgInfo.channels .. self.cfgInfo.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck)
    self.config:Write(self.cfgInfo.channels, self.currentChannels)

    self.config:Write(self.cfgInfo.length .. self.cfgInfo.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck)
    self.config:Write(self.cfgInfo.length, self.currentLength)
    self.config:Write(self.cfgInfo.length .. self.cfgInfo.conditional, self.currentLengthRelationCombo)

    self.config:Write(self.cfgInfo.sampleRate .. self.cfgInfo.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck)
    self.config:Write(self.cfgInfo.sampleRate, self.currentSampleRate)

    self.config:Write(self.cfgInfo.bitDepth .. self.cfgInfo.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck)
    self.config:Write(self.cfgInfo.bitDepth, self.currentBitDepth)

    self.config:Write(self.cfgInfo.peak .. self.cfgInfo.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck)
    self.config:Write(self.cfgInfo.peak, self.currentPeak)
    self.config:Write(self.cfgInfo.peak .. self.cfgInfo.conditional, self.currentPeakRelationCombo)

    self.config:Write(self.cfgInfo.loudness .. self.cfgInfo.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck)
    self.config:Write(self.cfgInfo.loudness, self.currentLoudness)
    self.config:Write(self.cfgInfo.loudness .. self.cfgInfo.conditional, self.currentLoudnessRelationCombo)

    self.config:Write(self.cfgInfo.silenceIn .. self.cfgInfo.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck)
    self.config:Write(self.cfgInfo.silenceIn, self.currentSilenceIn)

    self.config:Write(self.cfgInfo.silenceOut .. self.cfgInfo.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck)
    self.config:Write(self.cfgInfo.silenceOut, self.currentSilenceOut)
end

function GuiSrcValidator:CopyToClipboard()
    local output <const> = {}
    for _, property in pairs(GuiSrcValidator.Properties) do
        table.insert(output, property.title .. "\t")
    end

    table.insert(output, "\n")

    for _, data in pairs(self.validator.data) do
        for _, property in ipairs(ValidatorProperty.ExportStrings) do
            table.insert(output, tostring(data[property]) .. "\t")
        end
        table.insert(output, "\n")
    end

    local outputString = ""

    for _, value in pairs(output) do
        outputString = outputString .. value
    end

    ImGui.SetClipboardText(self.ctx, outputString)
end

function GuiSrcValidator:PrintToCSV()
    local defaultPath <const> = self.config:ReadString(self.cfgInfo.csvPath) or FileSys.Path.Default()
    local extensionList <const> = "CSV (.csv)\0*.csv\0\0"
    local windowTitle <const> = "Save CSV to location"

    local directory <const>, _, _ = FileSys.Path.Parse(defaultPath)
    local path <const> = FileSys.SaveDialog(windowTitle, directory, self:CreateCSVFileName(), extensionList)

    if Str.IsNilOrEmpty(path) then return end

    local file <close>, err <const> = io.open(path, "w")

    if not file then
        reaper.ShowConsoleMsg(("Could not open %s for PrintToCSV.\n Returned following error: %s"):format(path, err))
        return
    end

    do -- write headers
        for _, property in pairs(GuiSrcValidator.Properties) do
            file:write(property.title .. ",")
        end
        file:write("\n")
    end

    do -- write data
        for _, data in pairs(self.validator.data) do
            for _, property in ipairs(ValidatorProperty.ExportStrings) do
                file:write(tostring(data[property]) .. ",")
            end
            file:write("\n")
        end
    end

    self.config:Write(self.cfgInfo.csvPath, path)
end

GuiSrcValidator.TableFlag = {
    { "Resizable",            ImGui.TableFlags_Resizable },
    { "Fixed Fit",            ImGui.TableFlags_SizingFixedFit },
    { "Stretch Proportional", ImGui.TableFlags_SizingStretchProp }
}

function GuiSrcValidator:Menu_TableView()
    if ImGui.BeginMenu(self.ctx, "Layout") then
        for index, flag in ipairs(GuiSrcValidator.TableFlag) do
            self:ImGui_RadioTableFlags(index, flag[1], flag[2])
        end

        ImGui.EndMenu(self.ctx);
    end
end

function GuiSrcValidator:ImGui_RadioTableFlags(flagNumber, name, flag)
    if ImGui.RadioButton(self.ctx, name, self.radioFlags == flagNumber) then
        if self.radioFlags ~= flagNumber then
            self.radioFlags = flagNumber
            self.tableFlags = flag
        end
    end
end

function GuiSrcValidator:Menu_Detection()
    if ImGui.BeginMenu(self.ctx, "Detection") then
        if ImGui.RadioButton(self.ctx, "Peak", self.detectionAlgorithm == 0) then
            self.detectionAlgorithm = 0;
        end
        if ImGui.RadioButton(self.ctx, "RMS", self.detectionAlgorithm == 1) then
            self.detectionAlgorithm = 1;
        end

        local speed <const> = 1.0
        local min <const> = 1
        local max <const> = 8192

        _, self.bufferSize = ImGui.DragInt(self.ctx, "Buffer Size", self.bufferSize, speed, min, max)
        _, self.threshold = ImGui.SliderDouble(self.ctx, "Silence Threshold", self.threshold, -144.0, 0, "%.1f")

        ImGui.EndMenu(self.ctx);
    end
end

function GuiSrcValidator:Menu_ColorSelector()
    if ImGui.BeginMenu(self.ctx, "Validation Color") then
        local min <const> = 0
        local max <const> = 255
        local speed <const> = 1
        local flag <const> = ImGui.SliderFlags_AlwaysClamp

        _, self.curR = ImGui.DragInt(self.ctx, "R##ColSelRed", self.curR, speed, min, max, nil, flag)
        _, self.curG = ImGui.DragInt(self.ctx, "G##ColSelGre", self.curG, speed, min, max, nil, flag)
        _, self.curB = ImGui.DragInt(self.ctx, "B##ColSelBlu", self.curB, speed, min, max, nil, flag)

        CurColor = Color.CreateRGBA(self.curR, self.curG, self.curB)

        ImGui.EndMenu(self.ctx)
    end
end