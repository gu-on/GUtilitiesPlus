-- @version 1.0
-- @noindex

--#region ValidatorData

ValidatorData = Object:extend()

function ValidatorData:new()
    self.selected = false
    self.path = ""
    self.index = 0
    self.name = ""
    self.fileFormat = ""
    self.channelCount = 0
    self.length = 0
    self.sampleRate = 0
    self.bitDepth = 0
    self.peak = 0
    self.loudness = 0
    self.silenceIn = 0
    self.silenceOut = 0
    self.isZeroStart = false
    self.isZeroEnd = false
    self.hasRegion = false
    self.isMono = false
end

SilenceDetectionAlgorithm = {
    Peak = 0,
    RMS = 1
}

function ValidatorData:__eq(other)
    return other:is(ValidatorData) and self.path == other.path
end

--#endregion ValidatorData

--#region ValidatorProperty

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

--#endregion ValidatorProperty

--#region SourceValidator

SrcValidator = Object:extend()

function SrcValidator:new()
    self.data = {}
    self.items = Items()

    self.progBar = {}
    self.progBar.gui = {}
    self.progBar.num = 0
    self.progBar.denom = 0
end

function SrcValidator:FillItemsFromProject()
    table.clear(self.data)
    self.items:FillAll()
    self.progBar.gui = nil
end

function SrcValidator:FillItemsFromSelection()
    table.clear(self.data)
    self.items:FillSelected()
    self.progBar.gui = nil
end

function SrcValidator:TryFillDataSync()
    if reaper.MB("Reaper will appear unresponsive while your items are processed.\nDo you want to continue?", "Warning", MessageBoxType.OKCANCEL) == MessageBoxReturn.CANCEL then
        table.clear(self.items.array)
    end

    if table.isEmpty(self.items.array) then return end

    while not table.isEmpty(self.items.array) do
        self:FillData()
    end
end

function SrcValidator:TryFillDataAsync()
    if table.isEmpty(self.items.array) then
        self.progBar.gui = nil
        return
    end

    if self.progBar.gui == nil then
        self:InitProgressBar(#self.items.array)
    end

    if self.progBar.gui ~= nil then
        if self.progBar.gui.fraction >= 1 then
            self.progBar.gui = nil
        elseif not reaper.ImGui_ValidatePtr(self.progBar.gui.ctx, "ImGui_Context*") then
            self.progBar.gui = nil
        else
            reaper.defer(function () self:FillData() end)
        end
    end
end

function SrcValidator:InitProgressBar(count)
    self.progBar.num = 0
    self.progBar.denom = count
    self.progBar.gui = ProgressBar("progress bar")
    self.progBar.gui:Loop()
end

function SrcValidator:FillData()
    self.progBar.num = self.progBar.num + 1

    if self.progBar.gui ~= nil then
        self.progBar.gui.fraction = self.progBar.num / self.progBar.denom
    end

    if not table.isEmpty(self.items.array) then
        local item <const> = self.items.array[1]
        local takePtr <const> = item:GetActiveTakePtr()
        local take <const> = takePtr ~= nil and Take(takePtr) or nil
        local sourcePtr <const> = take ~= nil and take:GetSourcePtr() or nil
        local source <const> = (sourcePtr ~= nil) and Source(sourcePtr) or nil

        if source == nil or not source:IsValid() then goto removeItem end

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
        data.silenceIn = self.detectionAlgorithm == SilenceDetectionAlgorithm.Peak and
            source:GetTimeToPeak(self.bufferSize, self.silenceThreshold) or
            source:GetTimeToRMS(self.bufferSize, self.silenceThreshold)
        data.silenceOut = self.detectionAlgorithm == SilenceDetectionAlgorithm.Peak and
            source:GetTimeToPeakR(self.bufferSize, self.silenceThreshold) or
            source:GetTimeToRMSR(self.bufferSize, self.silenceThreshold)
        data.isZeroStart = source:IsFirstSampleZero(Maths.DB2VOL(self.silenceThreshold))
        data.isZeroEnd = source:IsLastSampleZero(Maths.DB2VOL(self.silenceThreshold))
        data.hasRegion = source:HasLoopMarker()
        data.isMono = source:IsMono()

        table.insert(self.data, data)
    end

    ::removeItem::

    table.remove(self.items.array, 1)

    if self.progBar.gui ~= nil and self.progBar.gui.shouldTerminate then
        table.clear(self.items.array)
    end
end

function SrcValidator:UpdateSettings(algorithm, threshold, bufferSize)
    self.detectionAlgorithm = algorithm
    self.silenceThreshold = threshold
    self.bufferSize = bufferSize
end

--#endregion SourceValidator

--#region Selections

AudioFormatSelection = Object:extend()

function AudioFormatSelection:new(name)
    self.isSelected = false
    self.name = name
end

--#endregion Selections

--#region GuiSrcValidator

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

function GuiSrcValidator:new(name, undoText, isAsync)
    GuiSrcValidator.super.new(self, name, undoText)
    self.validator = SrcValidator()
    self.isAsync = isAsync

    -- config
    self.config = Config(FileSys.GetRawName(name))
    self.config.csvPath = "csvPath"
    self.config.radioFlags = "radioFlags"
    self.config.shortTitles = "shortTitles"
    self.config.algorithm = "algorithm"
    self.config.bufferSize = "bufferSize"
    self.config.threshold = "threshold"
    self.config.rgb = "rgb"
    self.config.fileFormat = "fileFormat"
    self.config.channels = "channels"
    self.config.length = "length"
    self.config.sampleRate = "sampleRate"
    self.config.bitDepth = "bitDepth"
    self.config.peak = "peak"
    self.config.loudness = "loudness"
    self.config.silenceIn = "silenceIn"
    self.config.silenceOut = "silenceOut"
    self.config.conditional = "conditional"
    self.config.shouldCheck = "shouldCheck"

    self.isShortTitles = self.config:Read(self.config.shortTitles) or false
    self.radioFlags = self.config:Read(self.config.radioFlags) or 1
    self.tableFlags = GuiSrcValidator.TableFlag[self.radioFlags][2]
    self.threshold = self.config:Read(self.config.threshold) or -144.0
    self.detectionAlgorithm = self.config:Read(self.config.algorithm) or 0
    self.bufferSize = self.config:Read(self.config.bufferSize) or 32
    self.popUp = "Deviations" -- used as an id to keep track of popup

    GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck =
        self.config:Read(self.config.fileFormat .. self.config.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck =
        self.config:Read(self.config.channels .. self.config.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck =
        self.config:Read(self.config.length .. self.config.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck =
        self.config:Read(self.config.sampleRate .. self.config.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck =
        self.config:Read(self.config.bitDepth .. self.config.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck =
        self.config:Read(self.config.peak .. self.config.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck =
        self.config:Read(self.config.loudness .. self.config.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck =
        self.config:Read(self.config.silenceIn .. self.config.shouldCheck)
    GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck =
        self.config:Read(self.config.silenceOut .. self.config.shouldCheck)

    self.currentFileFormat = self.config:Read(self.config.fileFormat) or reaper.AudioFormats[1]
    self.currentChannels = self.config:Read(self.config.channels) or 2
    self.currentLength = self.config:Read(self.config.length) or 0
    self.currentLengthRelationCombo = self.config:Read(self.config.length .. self.config.conditional) or '<'
    self.currentSampleRate = self.config:Read(self.config.sampleRate) or 44100
    self.currentBitDepth = self.config:Read(self.config.bitDepth) or 24
    self.currentPeak = self.config:Read(self.config.peak) or 0
    self.currentPeakRelationCombo = self.config:Read(self.config.peak .. self.config.conditional) or '<'
    self.currentLoudness = self.config:Read(self.config.loudness) or 0
    self.currentLoudnessRelationCombo = self.config:Read(self.config.loudness .. self.config.conditional) or '<'
    self.currentSilenceIn = self.config:Read(self.config.silenceIn) or 0
    self.currentSilenceOut = self.config:Read(self.config.silenceOut) or 0

    -- colors
    local colors <const> = Col.GetColorTable(self.config:Read(self.config.rgb))
    self.curR = colors.red or 255
    self.curB = colors.blue or 0
    self.curG = colors.green or 0

    -- gui
    self.windowWidth = 1280
    self.windowHeight = 720
    self.windowFlags = self.windowFlags + reaper.ImGui_WindowFlags_MenuBar()
    self.relationalComboWidth = self.font.size * 2 + 10
end

function GuiSrcValidator:CreateCSVFileName()
    local t <const> = os.date("*t")
    local projectName = "SourceValidator_" .. reaper.GetProjectName(THIS_PROJECT)
    if not GUtil.IsNilOrEmpty(projectName) then
        projectName = projectName .. "_"
    end
    return projectName ..
        t.year .. "_" .. t.month .. "_" .. t.day .. "_" .. t.hour .. "_" .. t.min .. "_" .. t.sec .. ".csv"
end

function GuiSrcValidator:CurrentColor()
    return Col.CreateRGBA(self.curR, self.curG, self.curB)
end

function GuiSrcValidator:AsyncFrame()
    -- check state change
    if reaper.ImGui_BeginMenuBar(self.ctx) then
        if reaper.ImGui_BeginMenu(self.ctx, "File") then
            if reaper.ImGui_MenuItem(self.ctx, "Copy") then
                self:CopyToClipboard();
            end

            if reaper.ImGui_MenuItem(self.ctx, "Export CSV...") then
                self:PrintToCSV();
            end

            reaper.ImGui_EndMenu(self.ctx)
        end

        if reaper.ImGui_BeginMenu(self.ctx, "Settings") then
            self:Menu_TableView();
            self:Menu_Detection();
            self:Menu_ColorSelector();
            _, self.isShortTitles = reaper.ImGui_Checkbox(self.ctx, "Use Short Titles", self.isShortTitles);

            reaper.ImGui_EndMenu(self.ctx);
        end
        reaper.ImGui_EndMenuBar(self.ctx)
    end

    if reaper.ImGui_Button(self.ctx, "Check All Items") then
        self.validator:UpdateSettings(self.detectionAlgorithm, self.threshold, self.bufferSize)
        self.validator:FillItemsFromProject()
    end

    reaper.ImGui_SameLine(self.ctx)

    if reaper.ImGui_Button(self.ctx, "Check Selected Items") then
        self.validator:UpdateSettings(self.detectionAlgorithm, self.threshold, self.bufferSize)
        self.validator:FillItemsFromSelection()
    end

    reaper.ImGui_SameLine(self.ctx)

    if reaper.ImGui_Button(self.ctx, "Set Validation Settings") then
        reaper.ImGui_OpenPopup(self.ctx, self.popUp)
    end

    if reaper.ImGui_BeginPopup(self.ctx, self.popUp) then
        local offsetA <const> = self.font.size * 10
        local offsetB <const> = offsetA + self.relationalComboWidth + 4

        reaper.ImGui_Text(self.ctx, "Validation Toggle")
        reaper.ImGui_Separator(self.ctx)

        self:DrawCheck_FileFormat(offsetB);
        self:DrawCheck_ChannelCount(offsetB);
        self:DrawCheck_Length(offsetA, offsetB);
        self:DrawCheck_SampleRate(offsetB);
        self:DrawCheck_BitDepth(offsetB);
        self:DrawCheck_Peak(offsetA, offsetB);
        self:DrawCheck_Loudness(offsetA, offsetB);
        self:DrawCheck_SilenceForward(offsetB);
        self:DrawCheck_SilenceBackward(offsetB);

        reaper.ImGui_EndPopup(self.ctx)
    end

    self.validator:TryFillDataAsync()

    if reaper.ImGui_BeginTable(self.ctx, "Items", #GuiSrcValidator.Properties, self.tableFlags) then
        reaper.ImGui_TableNext(self.ctx)
        for _, property in pairs(GuiSrcValidator.Properties) do
            reaper.ImGui_TableHeader(self.ctx, self.isShortTitles and property.abbreviation or property.title)

            if reaper.ImGui_IsItemHovered(self.ctx) then
                reaper.ImGui_BeginTooltip(self.ctx)
                reaper.ImGui_Text(self.ctx, property.toolTip)
                reaper.ImGui_EndTooltip(self.ctx)
            end
        end

        for _, data in pairs(self.validator.data) do
            reaper.ImGui_TableNext(self.ctx)
            reaper.ImGui_Text(self.ctx, tostring(data.index)); -- index

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

        reaper.ImGui_EndTable(self.ctx)
    end
end

function GuiSrcValidator:SyncFrame()
    Debug:Log("Processing, please wait...\n")
    self.validator:UpdateSettings(self.detectionAlgorithm, self.threshold, self.bufferSize)
    self.validator:FillItemsFromProject()
    self.validator:TryFillDataSync()
    if not table.isEmpty(self.validator.data) then
        self:PrintToCSV()
    end
    Debug:Log("Final source media items processed: %i\n", #self.validator.data)
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
    reaper.ImGui_TableNextColumnEntry(self.ctx, name, Col.White)
end

function GuiSrcValidator:DrawTable_FileFormat(fileFormat)
    fileFormat = string.upper(fileFormat)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck and fileFormat ~= self.currentFileFormat) and
        self:CurrentColor() or Col.White
    reaper.ImGui_TableNextColumnEntry(self.ctx, string.format("%s", fileFormat), col)
end

function GuiSrcValidator:DrawTable_ChannelCount(channelCount)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck and channelCount ~= self.currentChannels) and
        self:CurrentColor() or Col.White
    reaper.ImGui_TableNextColumnEntry(self.ctx, channelCount, col)
end

function GuiSrcValidator:DrawTable_Length(length)
    local col = 0
    if self.currentLengthRelationCombo == '<' then
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck and length >= self.currentLength) and
            self:CurrentColor() or Col.White
    else
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck and length <= self.currentLength) and
            self:CurrentColor() or Col.White
    end
    reaper.ImGui_TableNextColumnEntry(self.ctx, string.format("%.3f s", length), col)
end

function GuiSrcValidator:DrawTable_SampleRate(sampleRate)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck and sampleRate ~= self.currentSampleRate) and
        self:CurrentColor() or Col.White
    reaper.ImGui_TableNextColumnEntry(self.ctx, string.format("%.1f kHz", sampleRate / 1000), col)
end

function GuiSrcValidator:DrawTable_BitDepth(bitDepth)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck and bitDepth ~= self.currentBitDepth) and
        self:CurrentColor() or Col.White
    reaper.ImGui_TableNextColumnEntry(self.ctx, bitDepth, col)
end

function GuiSrcValidator:DrawTable_Peak(peak)
    local col = 0
    if self.currentPeakRelationCombo == '<' then
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck and peak >= self.currentPeak) and
            self:CurrentColor() or Col.White
    else
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck and peak <= self.currentPeak) and
            self:CurrentColor() or Col.White
    end
    reaper.ImGui_TableNextColumnEntry(self.ctx, string.format("%.1f", peak), col)
end

function GuiSrcValidator:DrawTable_Loudness(loudness)
    local col = 0
    if self.currentLoudnessRelationCombo == '<' then
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck and loudness >= self.currentLoudness) and
            self:CurrentColor() or Col.White
    else
        col = (GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck and loudness <= self.currentLoudness) and
            self:CurrentColor() or Col.White
    end
    reaper.ImGui_TableNextColumnEntry(self.ctx, string.format("%.1f", loudness), col)
end

function GuiSrcValidator:DrawTable_SilenceForward(silenceIn)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck and silenceIn < self.currentSilenceIn) and
        self:CurrentColor() or Col.White
    reaper.ImGui_TableNextColumnEntry(self.ctx, string.format("%.3f s", silenceIn), col)
end

function GuiSrcValidator:DrawTable_SilenceBackward(silenceOut)
    local col <const> = (GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck and silenceOut < self.currentSilenceOut) and
        self:CurrentColor() or Col.White
    reaper.ImGui_TableNextColumnEntry(self.ctx, string.format("%.3f s", silenceOut), col)
end

function GuiSrcValidator:DrawTable_IsZeroStart(isZeroStart)
    reaper.ImGui_TableNextColumnEntry(self.ctx, isZeroStart and "o" or "x", Col.White)
end

function GuiSrcValidator:DrawTable_IsZeroEnd(isZeroEnd)
    reaper.ImGui_TableNextColumnEntry(self.ctx, isZeroEnd and "o" or "x", Col.White)
end

function GuiSrcValidator:DrawTable_HasRegion(hasRegion)
    reaper.ImGui_TableNextColumnEntry(self.ctx, hasRegion and "o" or "x", Col.White)
end

function GuiSrcValidator:DrawTable_IsMono(isMono)
    reaper.ImGui_TableNextColumnEntry(self.ctx, isMono and "o" or "x", Col.White)
end

function GuiSrcValidator:DrawCheck_FileFormat(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck =
        reaper.ImGui_Checkbox(self.ctx, "File Format",
            GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck);
    reaper.ImGui_SameLine(self.ctx, offset);
    self:FileFormatCombo();
end

function GuiSrcValidator:FileFormatCombo()
    if reaper.ImGui_BeginCombo(self.ctx, "##CurFileFormat", self.currentFileFormat) then
        for _, data in pairs(GuiSrcValidator.AudioFormatSelections) do
            if reaper.ImGui_Selectable(self.ctx, data.name, data.isSelected) then
                self.currentFileFormat = data.name;
            end
        end
        reaper.ImGui_EndCombo(self.ctx);
    end
end

function GuiSrcValidator:DrawCheck_ChannelCount(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck =
        reaper.ImGui_Checkbox(self.ctx, "Channels",
            GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck)

    reaper.ImGui_SameLine(self.ctx, offset);

    _, self.currentChannels =
        reaper.ImGui_InputInt(self.ctx, "##CurChannels", self.currentChannels)
end

function GuiSrcValidator:RelationalCombo(label, relationalSelection, relations)
    reaper.ImGui_PushItemWidth(self.ctx, self.relationalComboWidth)
    local ret = relationalSelection
    if reaper.ImGui_BeginCombo(self.ctx, label, relationalSelection) then
        for _, type in pairs(relations) do
            local retval <const>, _ = reaper.ImGui_Selectable(self.ctx, type, false)
            if retval then
                ret = type
            end
        end
        reaper.ImGui_EndCombo(self.ctx)
    end
    reaper.ImGui_PopItemWidth(self.ctx)
    return ret
end

function GuiSrcValidator:DrawCheck_Length(offsetA, offsetB)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck =
        reaper.ImGui_Checkbox(self.ctx, "Length",
            GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck)

    reaper.ImGui_SameLine(self.ctx, offsetA)
    self.currentLengthRelationCombo =
        self:RelationalCombo("##RelationalLength", self.currentLengthRelationCombo, { "<", ">" });
    reaper.ImGui_SameLine(self.ctx, offsetB)

    _, self.currentLength =
        reaper.ImGui_InputDouble(self.ctx, "##CurLength", self.currentLength)
end

function GuiSrcValidator:DrawCheck_SampleRate(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck =
        reaper.ImGui_Checkbox(self.ctx, "Sample Rate",
            GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck)

    reaper.ImGui_SameLine(self.ctx, offset)

    _, self.currentSampleRate =
        reaper.ImGui_InputInt(self.ctx, "##CurSampleRate", self.currentSampleRate)
end

function GuiSrcValidator:DrawCheck_BitDepth(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck =
        reaper.ImGui_Checkbox(self.ctx, "Bit Depth",
            GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck)

    reaper.ImGui_SameLine(self.ctx, offset)

    _, self.currentBitDepth =
        reaper.ImGui_InputInt(self.ctx, "##CurBitDepth", self.currentBitDepth);
end

function GuiSrcValidator:DrawCheck_Peak(offsetA, offsetB)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck =
        reaper.ImGui_Checkbox(self.ctx, "Peak",
            GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck)

    reaper.ImGui_SameLine(self.ctx, offsetA)
    self.currentPeakRelationCombo =
        self:RelationalCombo("##RelationalPeak", self.currentPeakRelationCombo, { '<', '>' });
    reaper.ImGui_SameLine(self.ctx, offsetB)

    _, self.currentPeak =
        reaper.ImGui_InputDouble(self.ctx, "##CurPeak", self.currentPeak);
end

function GuiSrcValidator:DrawCheck_Loudness(offsetA, offsetB)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck =
        reaper.ImGui_Checkbox(self.ctx, "Loudness",
            GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck)

    reaper.ImGui_SameLine(self.ctx, offsetA)
    self.currentLoudnessRelationCombo =
        self:RelationalCombo("##RelationalLoudness", self.currentLoudnessRelationCombo, { '<', '>' });
    reaper.ImGui_SameLine(self.ctx, offsetB)

    _, self.currentLoudness =
        reaper.ImGui_InputDouble(self.ctx, "##CurLoudness", self.currentLoudness);
end

function GuiSrcValidator:DrawCheck_SilenceForward(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck =
        reaper.ImGui_Checkbox(self.ctx, "Silence In",
            GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck)

    reaper.ImGui_SameLine(self.ctx, offset);

    _, self.currentSilenceIn =
        reaper.ImGui_InputDouble(self.ctx, "##CurSilenceIn", self.currentSilenceIn);
end

function GuiSrcValidator:DrawCheck_SilenceBackward(offset)
    _, GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck =
        reaper.ImGui_Checkbox(self.ctx, "Silence Out",
            GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck)

    reaper.ImGui_SameLine(self.ctx, offset);

    _, self.currentSilenceOut =
        reaper.ImGui_InputDouble(self.ctx, "##CurSilenceOut", self.currentSilenceOut);
end

function GuiSrcValidator:OnClose()
    self.config:Write(self.config.shortTitles, self.isShortTitles)
    self.config:Write(self.config.threshold, self.threshold)
    self.config:Write(self.config.radioFlags, self.radioFlags)
    self.config:Write(self.config.algorithm, self.detectionAlgorithm)
    self.config:Write(self.config.bufferSize, self.bufferSize)
    self.config:Write(self.config.rgb, Col.CreateRGBA(self.curR, self.curG, self.curB))

    self.config:Write(self.config.fileFormat .. self.config.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.FileFormat].shouldCheck)
    self.config:Write(self.config.fileFormat, self.currentFileFormat)

    self.config:Write(self.config.channels .. self.config.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.Channels].shouldCheck)
    self.config:Write(self.config.channels, self.currentChannels)

    self.config:Write(self.config.length .. self.config.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.Length].shouldCheck)
    self.config:Write(self.config.length, self.currentLength)
    self.config:Write(self.config.length .. self.config.conditional, self.currentLengthRelationCombo)

    self.config:Write(self.config.sampleRate .. self.config.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.SampleRate].shouldCheck)
    self.config:Write(self.config.sampleRate, self.currentSampleRate)

    self.config:Write(self.config.bitDepth .. self.config.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.BitDepth].shouldCheck)
    self.config:Write(self.config.bitDepth, self.currentBitDepth)

    self.config:Write(self.config.peak .. self.config.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.Peak].shouldCheck)
    self.config:Write(self.config.peak, self.currentPeak)
    self.config:Write(self.config.peak .. self.config.conditional, self.currentPeakRelationCombo)

    self.config:Write(self.config.loudness .. self.config.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.Loudness].shouldCheck)
    self.config:Write(self.config.loudness, self.currentLoudness)
    self.config:Write(self.config.loudness .. self.config.conditional, self.currentLoudnessRelationCombo)

    self.config:Write(self.config.silenceIn .. self.config.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceIn].shouldCheck)
    self.config:Write(self.config.silenceIn, self.currentSilenceIn)

    self.config:Write(self.config.silenceOut .. self.config.shouldCheck,
        GuiSrcValidator.Properties[ValidatorProperty.Type.SilenceOut].shouldCheck)
    self.config:Write(self.config.silenceOut, self.currentSilenceOut)
end

function GuiSrcValidator:CopyToClipboard()
    local output = {}
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

    reaper.ImGui_SetClipboardText(self.ctx, outputString)
end

function GuiSrcValidator:PrintToCSV()
    local defaultPath <const> = self.config:Read(self.config.csvPath) or FileSys.Path.Default()
    local extensionList <const> = "CSV (.csv)\0*.csv\0\0"
    local windowTitle <const> = "Save CSV to location"

    local directory <const>, _, _ = FileSys.Path.Parse(defaultPath)
    local path <const> = FileSys.SaveDialog(windowTitle, directory, self:CreateCSVFileName(), extensionList)

    ---@diagnostic disable-next-line: param-type-mismatch
    if GUtil.IsNilOrEmpty(path) then return end

    local file <close> = File(path, File.Mode.Write)

    -- write headers
    for _, property in pairs(GuiSrcValidator.Properties) do
        file:Write(property.title .. ",")
    end
    file:Write("\n")

    -- write data
    for _, data in pairs(self.validator.data) do
        for _, property in ipairs(ValidatorProperty.ExportStrings) do
            file:Write(tostring(data[property]) .. ",")
        end
        file:Write("\n")
    end

    self.config:Write(self.config.csvPath, path)
end

GuiSrcValidator.TableFlag = {
    { "Resizable",            reaper.ImGui_TableFlags_Resizable() },
    { "Fixed Fit",            reaper.ImGui_TableFlags_SizingFixedFit() },
    { "Stretch Proportional", reaper.ImGui_TableFlags_SizingStretchProp() }
}

function GuiSrcValidator:Menu_TableView()
    if reaper.ImGui_BeginMenu(self.ctx, "Layout") then
        for index, flag in ipairs(GuiSrcValidator.TableFlag) do
            self:ImGui_RadioTableFlags(index, flag[1], flag[2])
        end

        reaper.ImGui_EndMenu(self.ctx);
    end
end

function GuiSrcValidator:ImGui_RadioTableFlags(flagNumber, name, flag)
    if reaper.ImGui_RadioButton(self.ctx, name, self.radioFlags == flagNumber) then
        if self.radioFlags ~= flagNumber then
            self.radioFlags = flagNumber
            self.tableFlags = flag
        end
    end
end

function GuiSrcValidator:Menu_Detection()
    if reaper.ImGui_BeginMenu(self.ctx, "Detection") then
        if reaper.ImGui_RadioButton(self.ctx, "Peak", self.detectionAlgorithm == SilenceDetectionAlgorithm.Peak) then
            self.detectionAlgorithm = SilenceDetectionAlgorithm.Peak;
        end
        if reaper.ImGui_RadioButton(self.ctx, "RMS", self.detectionAlgorithm == SilenceDetectionAlgorithm.RMS) then
            self.detectionAlgorithm = SilenceDetectionAlgorithm.RMS;
        end

        local speed <const> = 1.0;
        local min <const> = 1;
        local max <const> = 8192;

        _, self.bufferSize = reaper.ImGui_DragInt(self.ctx, "Buffer Size", self.bufferSize, speed, min, max);
        _, self.threshold = reaper.ImGui_SliderDouble(self.ctx, "Silence Threshold", self.threshold, -144.0, 0, "%.1f");

        reaper.ImGui_EndMenu(self.ctx);
    end
end

function GuiSrcValidator:Menu_ColorSelector()
    if reaper.ImGui_BeginMenu(self.ctx, "Validation Color") then
        local min <const> = 0;
        local max <const> = 255;
        local speed <const> = 1;
        local flag <const> = reaper.ImGui_SliderFlags_AlwaysClamp();

        _, self.curR = reaper.ImGui_DragInt(self.ctx, "R##ColSelRed", self.curR, speed, min, max, nil, flag);
        _, self.curG = reaper.ImGui_DragInt(self.ctx, "G##ColSelGre", self.curG, speed, min, max, nil, flag);
        _, self.curB = reaper.ImGui_DragInt(self.ctx, "B##ColSelBlu", self.curB, speed, min, max, nil, flag);

        CurColor = Col.CreateRGBA(self.curR, self.curG, self.curB);

        reaper.ImGui_EndMenu(self.ctx);
    end
end

--#endregion GuiSrcValidator
