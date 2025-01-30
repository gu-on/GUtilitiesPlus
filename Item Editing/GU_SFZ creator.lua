-- @description SFZ creator
-- @author guonaudio
-- @version 1.2b
-- @changelog
--   Match require case to path case for Unix systems
-- @about
--   Move items to first found track with the same name

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_classic')
require('Lua.gutil_filesystem')
require('Lua.gutil_table')
require('Reaper.gutil_config')
require('Reaper.gutil_gui')
require('Reaper.gutil_item')
require('Reaper.gutil_os')
require('Reaper.gutil_project')
require('Reaper.gutil_source')
require('Reaper.gutil_take')

---@alias MidiKey "C"|"C#"|"D"|"D#"|"E"|"F"|"F#"|"G"|"G#"|"A"|"A#"|"B"
---@alias MidiValue -1|0|1|2|3|4|5|6|7|8|9|10|11

---@class (exact) MidiPair
---@field key MidiKey
---@field val MidiValue

---@class MIDI
---@field MAP MidiPair[] 
MIDI = {}

MIDI.MIN = 1
MIDI.MAX = 127
MIDI.OFFSET = 12
MIDI.NOTEPEROCTAVE = 12
MIDI.NA = -1
MIDI.MAP = {
    { key = "C" , val = 0 }, { key = "C#", val = 1  }, { key = "D",  val = 2  },
    { key = "D#", val = 3 }, { key = "E" , val = 4  }, { key = "F",  val = 5  },
    { key = "F#", val = 6 }, { key = "G" , val = 7  }, { key = "G#", val = 8  },
    { key = "A" , val = 9 }, { key = "A#", val = 10 }, { key = "B",  val = 11 }
}

---@param key MidiKey
---@return MidiValue
function MIDI.GetValue(key)
    for _, midi in pairs(MIDI.MAP) do
        if midi.key == key then return midi.val end
    end
    return MIDI.NA
end

---@param val MidiValue
---@return MidiKey
function MIDI.GetKey(val)
    for _, midi in pairs(MIDI.MAP) do
        if midi.val == val then return midi.key end
    end
    return tostring(MIDI.NA)
end

---Extracts musical note letter + sharp symbol (if relevant)
---@param input string
---@nodiscard
function MIDI.ExtractNote(input)
    if input == nil then return "" end
    local letters <const> = {}
    for letter in input:gmatch("%a+") do
        table.insert(letters, letter)
    end
    for letter in input:gmatch("#") do
        table.insert(letters, letter)
    end
    return table.concat(letters)
end

---Information relating to an individual sample
---@class (exact) Sample : Object
---@operator call: Sample
---@field name string
---@field ext string
---@field seq integer
---@field key MidiValue
---@field lokey integer
---@field hikey integer
---@field dyn integer
---@field lovel integer
---@field hivel integer
Sample = Object:extend()

---@param name string
---@param ext string
---@param seq string
---@param key string
---@param dyn string
---@param lovel string
---@param hivel string
function Sample:new(name, ext, seq, key, dyn, lovel, hivel)
    self.name = name
    self.ext = ext
    self.seq = seq and toint(Str.ExtractNumber(seq)) or MIDI.NA
    self.key = Str.IsNumber(key) and toint(key) or self:CalculateMIDIValue(key)
    self.lokey = MIDI.NA
    self.hikey = MIDI.NA
    self.dyn = toint(Str.ExtractNumber(dyn)) or MIDI.NA
    self.lovel = lovel and toint(Str.ExtractNumber(lovel)) or MIDI.NA
    self.hivel = hivel and toint(Str.ExtractNumber(hivel)) or MIDI.NA
end

---@param input string
---@return MidiValue
function Sample:CalculateMIDIValue(input)
    if Str.IsNilOrEmpty(input) then return MIDI.NA end

    local letter <const> = MIDI.ExtractNote(input) ---@cast letter MidiKey
    local number <const> = Str.ExtractNumber(input)

    -- todo: Check if number. Check if in MIDI range. Check if number letter note. Check if in MIDI range.
    return MIDI.OFFSET + MIDI.GetValue(letter) + number * MIDI.NOTEPEROCTAVE
end

---Info gleaned by looking at all the samples
---@class (exact) SampleAggregate
---@field lowestKey integer
---@field highestKey integer
---@field seqTotal integer
---@field dynTotal integer

---Index of the various tags within the name
---@class (exact) TagIndex
---@field seq integer
---@field key integer
---@field lovel integer
---@field hivel integer
---@field dyn integer

---@class SfzMaker : Object
---@operator call: SfzMaker
---@field index TagIndex
---@field samplesIn Sample[]
---@field samplesInfo SampleAggregate
---@field samplesOut Sample[]
SfzMaker = Object:extend()

function SfzMaker:new()
    self.index = {
        seq = MIDI.NA,
        key = MIDI.NA,
        lovel = MIDI.NA,
        hivel = MIDI.NA,
        dyn = MIDI.NA
    }

    self.samplesInfo = {
        lowestKey = MIDI.MAX,
        highestKey = MIDI.MIN,
        seqTotal = 0,
        dynTotal = 0
    }

    self.samplesIn = {}
    self.samplesOut = {}
end

function SfzMaker:SetTagTable(input)
    local tagTable <const> = self:ParseString(input)

    self.index = {
        seq   = SfzMaker:GetIndex(tagTable, "seq"  ),
        key   = SfzMaker:GetIndex(tagTable, "key"  ),
        dyn   = SfzMaker:GetIndex(tagTable, "dyn"  ),
        lovel = SfzMaker:GetIndex(tagTable, "lovel"),
        hivel = SfzMaker:GetIndex(tagTable, "hivel"),
    }
end

---@param input string
---@return table
function SfzMaker:ParseString(input)
    local output <const> = {}
    for word in string.gmatch(input, '([^_]+)') do
        table.insert(output, word)
    end
    return output
end

---@param t table
---@param key string
---@return integer
function SfzMaker:GetIndex(t, key)
    for i, value in ipairs(t) do
        if value == key then return i end
    end
    return MIDI.NA
end

---@param sample Sample
---@return string
function SfzMaker:ProcessName(sample)
    return
        "<region> sample=" .. sample.name .. "\t"
end

---@param sample Sample
---@return string
function SfzMaker:ProcessKey(sample)
    return sample.key == MIDI.NA and "" or
        "pitch_keycenter=" .. string.format("%03d", sample.key) .. "\t" ..
        "lokey=" .. string.format("%03d", sample.lokey) .. "\t" ..
        "hikey=" .. string.format("%03d", sample.hikey) .. "\t"
end

---@param sample Sample
---@return string
function SfzMaker:ProcessLoVel(sample)
    return sample.lovel == MIDI.NA and "" or
        "lovel=" .. string.format("%03d", sample.lovel) .. "\t"
end

---@param sample Sample
---@return string
function SfzMaker:ProcessHiVel(sample)
    return sample.hivel == MIDI.NA and "" or
        "hivel=" .. string.format("%03d", sample.hivel) .. "\t"
end

---@param sample Sample
---@return string
function SfzMaker:ProcessSeq(sample)
    if sample.seq == MIDI.NA then return "" end

    if self.samplesInfo.seqTotal <= 1 then return "" end

    return
        "seq_position=" .. string.format("%02d", sample.seq) .. "\t" ..
        "seq_length=" .. string.format("%02d", self.samplesInfo.seqTotal) .. "\t"
end

function SfzMaker:FillData()
    local project <const> = Project(THIS_PROJECT)
    local items <const> = project:GetSelectedItems()

    for _, item in pairs(items) do
        local take <const> = item:GetActiveTake()
        if not take:IsValid() then goto continue end

        local source <const> = take:GetSource()
        if not source:IsValid() then goto continue end

        local ext <const> = source:GetFileFormat()
        local name <const> = take:GetString("P_NAME")
        local tags <const> = self:ParseString(name)
        tags[-1] = "-1"

        local sample <const> = Sample(name, ext,
            tags[self.index.seq],
            tags[self.index.key],
            tags[self.index.dyn],
            tags[self.index.lovel],
            tags[self.index.hivel]
        )

        table.insert(self.samplesIn, sample)

        ::continue::
    end
end

---@param dyn integer
---@return table
function SfzMaker:GenerateVelocityMap(dyn)
    local t1 <const> = {}
    local dynSize <const> = MIDI.MAX / dyn
    local num = 0
    for i = 1, dyn do
        local t2 <const> = {}
        t2.min = math.ceil(num)
        num = num + dynSize
        t2.max = math.floor(num)
        if i == 1 then t2.min = MIDI.MIN end   -- 0 is MIDI off
        if i == dyn then t2.max = MIDI.MAX end -- floor sometimes rounds to 126, ensure max
        table.insert(t1, t2)
    end
    return t1
end

function SfzMaker:CreateSFZ()
    self.samplesInfo.lowestKey = MIDI.MAX
    self.samplesInfo.highestKey = MIDI.MIN
    self.samplesInfo.seqTotal = 0
    self.samplesInfo.dynTotal = 0

    -- get extremities
    for _, sample in pairs(self.samplesIn) do
        if sample.key > self.samplesInfo.highestKey then self.samplesInfo.highestKey = sample.key end
        if sample.key < self.samplesInfo.lowestKey then self.samplesInfo.lowestKey = sample.key end
        if sample.seq > self.samplesInfo.seqTotal then self.samplesInfo.seqTotal = sample.seq end
        if sample.dyn > self.samplesInfo.dynTotal then self.samplesInfo.dynTotal = sample.dyn end
    end

    -- update velocity
    if self.index.lovel == MIDI.NA and self.index.hivel == MIDI.NA and self.index.dyn ~= MIDI.NA then
        if self.samplesInfo.dynTotal > 0 then
            local velMap <const> = self:GenerateVelocityMap(self.samplesInfo.dynTotal)

            for _, sample in pairs(self.samplesIn) do
                sample.lovel = velMap[sample.dyn].min
                sample.hivel = velMap[sample.dyn].max
            end
        end
    end

    -- update lokey hikey
    if self.index.key ~= MIDI.NA then
        local keys <const> = {}
        for _, sample in pairs(self.samplesIn) do
            table.append(keys, sample.key)
        end

        table.sort(keys, function (a, b) return a < b end)

        local keyList <const> = {}
        for i, key in ipairs(keys) do
            local lastSample <const> = keys[i - 1]
            local nextSample <const> = keys[i + 1]

            local lokey = self.samplesInfo.lowestKey
            local hikey = self.samplesInfo.highestKey

            if lastSample ~= nil then
                local gap <const> = key - lastSample
                lokey = math.ceil(gap / 2) + lastSample
            end

            if nextSample ~= nil then
                local gap <const> = nextSample - key
                hikey = math.floor(gap / 2) + key
            end

            table.append(keyList, {
                key = key,
                lokey = lokey,
                hikey = hikey
            })
        end

        for _, sample in pairs(self.samplesIn) do
            sample.lokey = table.find(keyList, sample, "key").lokey
            sample.hikey = table.find(keyList, sample, "key").hikey
        end
    end

    -- fill output table
    for _, sample in pairs(self.samplesIn) do
        table.insert(self.samplesOut, {
            name = self:ProcessName(sample),
            seq = self:ProcessSeq(sample),
            lovel = self:ProcessLoVel(sample),
            hivel = self:ProcessHiVel(sample),
            key = self:ProcessKey(sample)
        })
    end

    table.sort(self.samplesOut, function (a, b)
        return a.key < b.key
    end)
end

---@class GuiSfzMaker : GuiBase
GuiSfzMaker = GuiBase:extend()

GuiSfzMaker.TooltipSize = 200

---@param name string
---@param undoText string
function GuiSfzMaker:new(name, undoText)
    GuiSfzMaker.super.new(self, name, undoText)

    self.windowFlags = self.windowFlags + ImGui.WindowFlags_MenuBar

    self.config = Config(FileSys.GetRawName(name)) ---@type Config
    self.cfgInfo = {}
    self.cfgInfo.input = "input"
    self.cfgInfo.csvPath = "csvPath"

    self.input = self.config:ReadString(self.cfgInfo.input)

    return self
end

function GuiSfzMaker:Update()
    local sfzMaker <const> = SfzMaker()

    sfzMaker:SetTagTable(self.input)
    sfzMaker:FillData()
    sfzMaker:CreateSFZ()

    self.output = ""
    for _, sample in pairs(sfzMaker.samplesOut) do
        self.output = self.output .. sample.name  .. "\t"
        self.output = self.output .. sample.seq   .. "\t"
        self.output = self.output .. sample.lovel .. "\t"
        self.output = self.output .. sample.hivel .. "\t"
        self.output = self.output .. sample.key   .. "\t"
        self.output = self.output .. "\n"
    end
end

---@return boolean
---@nodiscard
function GuiSfzMaker:HasProjectStateChanged()
    local newProjectState <const> = reaper.GetProjectStateChangeCount(THIS_PROJECT)

    if self.projectState ~= newProjectState then
        self.projectState = newProjectState
        return true
    end

    return false
end

function GuiSfzMaker:PrintToSFZ()
    local defaultPath <const> = self.config:ReadString(self.cfgInfo.csvPath) or FileSys.Path.Default()
    local extensionList <const> = "SFZ (.sfz)\0*.sfz\0\0"
    local windowTitle <const> = "Save SFZ to location"

    local directory <const>, _, _ = FileSys.Path.Parse(defaultPath)
    local project <const> = Project(THIS_PROJECT)
    local path <const> = FileSys.SaveDialog(windowTitle, directory, project:GetName() .. ".sfz", extensionList)

    if Str.IsNilOrEmpty(path) then return end

    local file <close>, err <const> = io.open(path, "w")

    if not file then
        reaper.ShowConsoleMsg(("Could not open %s for PrintToSFZ.\n Returned following error: %s"):format(path, err))
        return
    end

    file:write(self.output) -- todo add ".sfz" if doesn't contain ".sfz" as final 4 characters

    self.config:Write(self.cfgInfo.csvPath, path)
end

function GuiSfzMaker:DrawMenuItem(tag, tooltip, url)
    if ImGui.MenuItem(self.ctx, tag) then
        self.input = self.input .. tag
    end

    if ImGui.IsItemHovered(self.ctx) and ImGui.IsKeyPressed(self.ctx, ImGui.Key_F1) then
        Cmd.OpenURL(url)
    end

    if ImGui.IsItemHovered(self.ctx) then
        ImGui.SetNextWindowSize(self.ctx, GuiSfzMaker.TooltipSize, 0.0)
        if ImGui.BeginTooltip(self.ctx) then
            local textWrapPos <const> = 0.0 -- 0.0: wrap to end of window (or column)
            ImGui.PushTextWrapPos(self.ctx, textWrapPos)

            ImGui.Text(self.ctx, tooltip)
            ImGui.PopTextWrapPos(self.ctx)
            ImGui.EndTooltip(self.ctx)
        end
    end
end

function GuiSfzMaker:MenuBar()
    if ImGui.BeginMenuBar(self.ctx) then
        if ImGui.BeginMenu(self.ctx, "File") then
            if ImGui.MenuItem(self.ctx, "Copy") then
                ImGui.SetClipboardText(self.ctx, self.output)
            end
            if ImGui.MenuItem(self.ctx, "Export to SFZ") then
                self:PrintToSFZ()
            end
            ImGui.EndMenu(self.ctx)
        end

        if ImGui.BeginMenu(self.ctx, "Tags") then
            self:DrawMenuItem("key",
                "Corresponds to pitch_keycenter in SFZ. Can be a name (e.g. C#2) or a value (e.g. 49), but it doesn't support notation using flats (e.g. Cb2)",
                "https://sfzformat.com/opcodes/pitch_keycenter/")
            self:DrawMenuItem("seq", "Corresponds to seq_position in SFZ", "https://sfzformat.com/opcodes/seq_position/")
            self:DrawMenuItem("dyn",
                "Will automatically create lovel and hivel based on number of dyn layers. i.e. if there are 2 dyn, pairs will be split into 1_63 and 64_127",
                "https://sfzformat.com/opcodes/hivel/")
            self:DrawMenuItem("lovel", "Corresponds to lovel in SFZ", "https://sfzformat.com/opcodes/hivel/")
            self:DrawMenuItem("hivel", "Corresponds to hivel in SFZ", "https://sfzformat.com/opcodes/hivel/")
            ImGui.EndMenu(self.ctx)
        end
        ImGui.EndMenuBar(self.ctx)
    end
end

function GuiSfzMaker:InputText()
    local rv = nil
    local x <const>, _ = ImGui.GetContentRegionAvail(self.ctx)
    ImGui.SetNextItemWidth(self.ctx, x)
    rv, self.input = ImGui.InputText(self.ctx, "##Input", self.input)
    return rv
end

function GuiSfzMaker:OutputText()
    local x <const>, y <const> = ImGui.GetContentRegionAvail(self.ctx)
    ImGui.InputTextMultiline(self.ctx, "##OutputDisplay", self.output, x, y)
end

function GuiSfzMaker:Frame()
    self:MenuBar()

    if self:InputText() or self:HasProjectStateChanged() then
        self:Update()
    end

    self:OutputText()
end

function GuiSfzMaker:OnClose()
    self.config:Write(self.cfgInfo.input, self.input)
end

local scriptPath <const> = debug.getinfo(1).source

local _, filename <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = GuiSfzMaker(filename, "NA", true)

reaper.defer(function () gui:Loop() end)
