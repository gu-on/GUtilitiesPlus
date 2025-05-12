-- @description Reposition items
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Sets space between items 

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_filesystem')
require('Reaper.gutil_config')
require('Reaper.gutil_gui')
require('Reaper.gutil_item')
require('Reaper.gutil_project')
require('Reaper.gutil_track')

---@class ItemSpacer : GuiBase
---@operator call : ItemSpacer
ItemSpacer = GuiBase:extend()
ItemSpacer.FromLocationCount = 3
ItemSpacer.PositionModeCount = 4

---@alias ItemSpacerFromLocation
---| 0 # Start
---| 1 # Snap Offset
---| 2 # End

---@alias ItemSpacerPositionMode
---| 0 # In order
---| 1 # Across Tracks
---| 2 # Per Track
---| 3 # Align

---@param name string
---@param undoText string
function ItemSpacer:new(name, undoText)
    ItemSpacer.super.new(self, name, undoText)

    self.config = Config(FileSys.GetRawName(name))
    self.cfgInfo = {}

    self.cfgInfo.time = "time"
    self.cfgInfo.fromLocation = "fromLocation"
    self.cfgInfo.positionMode = "positionMode"

    self.time = self.config:ReadNumber(self.cfgInfo.time) or 0

    local fromLocation <const> = self.config:ReadNumber(self.cfgInfo.fromLocation) or 0 ---@cast fromLocation ItemSpacerFromLocation
    self.fromLocation = fromLocation

    local positionMode <const> = self.config:ReadNumber(self.cfgInfo.positionMode) or 0 ---@cast positionMode ItemSpacerPositionMode
    self.positionMode = positionMode
end

---@param index ItemSpacerFromLocation
---@return string
function ItemSpacer:GetFromLocationString(index)
    local cases <const> = {
        [0] = function() return "Start" end,
        [1] = function() return "Snap Offset"  end,
        [2] = function() return "End" end,
    } return (cases[index] or function() return "" end)()
end

---@param index ItemSpacerPositionMode
---@return string
function ItemSpacer:GetPositionModeString(index)
    local cases <const> = {
        [0] = function() return "In Order" end,
        [1] = function() return "Across Tracks" end,
        [2] = function() return "Per Track"  end,
        [3] = function() return "Align" end,
    } return (cases[index] or function() return "" end)()
end

---@param item Item
---@param index ItemSpacerFromLocation
---@return number
function ItemSpacer:GetStartPos(item, index)
    local cases <const> = {
        [0] = function() return item:GetStart() end,
        [1] = function() return item:GetStart() + item:GetValue("D_SNAPOFFSET") end,
        [2] = function() return item:GetEnd() end,
    } return (cases[index] or function() return 0 end)()
end

function ItemSpacer:DrawFromCombo()
    for i = 0, ItemSpacer.FromLocationCount - 1 do
        if ImGui.RadioButton(self.ctx, self:GetFromLocationString(i), self.fromLocation == i) then
            self.fromLocation = i
        end
    end
end

function ItemSpacer:DrawModeCombo()
    for i = 0, ItemSpacer.PositionModeCount - 1 do
        if ImGui.RadioButton(self.ctx, self:GetPositionModeString(i), self.positionMode == i) then
            self.positionMode = i
        end
    end
end

function ItemSpacer:Frame()
    if self.frameCounter == 1 then
        ImGui.SetKeyboardFocusHere(self.ctx)
    end

    self.time = select(2, ImGui.InputDouble(self.ctx, "Seconds", self.time))

    if ImGui.BeginCombo(self.ctx, "From", self:GetFromLocationString(self.fromLocation)) then
        self:DrawFromCombo()
        ImGui.EndCombo(self.ctx)
    end

    if ImGui.BeginCombo(self.ctx, "Mode", self:GetPositionModeString(self.positionMode)) then
        self:DrawModeCombo()
        ImGui.EndCombo(self.ctx)
    end

    if ImGui.Button(self.ctx, "Apply") or ImGuiExt.IsEnterKeyPressed(self.ctx) then
        self:Begin()
        self:Process()
        self.config:Write(self.cfgInfo.time, tostring(self.time))
        self.config:Write(self.cfgInfo.fromLocation, tostring(self.fromLocation))
        self.config:Write(self.cfgInfo.positionMode, tostring(self.positionMode))
        self:Complete(4)
    end
end

function ItemSpacer:Process()
    local project <const> = Project()
    local items = project:GetSelectedItems()
    local prevItem --[[@type Item]]= nil
    local firstItem --[[@type Item]] = nil

    if self.positionMode == 0 then -- In Order
        table.sort(items, function (a, b) return a:GetValue("D_POSITION") < b:GetValue("D_POSITION") end)
    end

    for index, item in ipairs(items) do
        if index == 1 then
            firstItem = item
            goto continue
        end

        if self.positionMode == 2 then -- Per Track
            if item:GetTrack() ~= prevItem:GetTrack() then goto continue end
        end

        if self.positionMode == 3 then -- Align
            if item:GetTrack() ~= prevItem:GetTrack() then
                item:SetValue("D_POSITION", firstItem:GetStart() + (self.fromLocation == 1 and firstItem:GetValue("D_SNAPOFFSET") - item:GetValue("D_SNAPOFFSET") or 0))
                goto continue
            end
        end

        item:SetValue("D_POSITION", self:GetStartPos(prevItem, self.fromLocation) + self.time - (self.fromLocation == 1 and item:GetValue("D_SNAPOFFSET") or 0))

        :: continue ::
        prevItem = item
    end
end

local scriptPath <const> = debug.getinfo(1).source

local _, filename <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = ItemSpacer(filename, "Set space between items")

reaper.defer(function () gui:Loop() end)