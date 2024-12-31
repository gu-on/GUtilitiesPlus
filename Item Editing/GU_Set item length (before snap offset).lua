-- @description Set item length before snap offset
-- @author guonaudio
-- @version 1.1
-- @changelog
--   Refactor to make better use of Lua Language Server
--   Fixed bug where Item with Take containing stretch markers wouldn't be affected
-- @about
--   Sets the length of the item to the left of its snap offset (in seconds)

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('lua.gutil_filesystem')
require('reaper.gutil_config')
require('reaper.gutil_gui')
require('reaper.gutil_item')
require('reaper.gutil_os')
require('reaper.gutil_project')
require('reaper.gutil_take')

---@class AdjusterBefore : GuiBase
AdjusterBefore = GuiBase:extend()

function AdjusterBefore:new(name, undoText)
    AdjusterBefore.super.new(self, name, undoText)

    self.windowFlags = self.windowFlags + ImGui.WindowFlags_AlwaysAutoResize

    self.configKey = "timeBeforeOffset"
    self.config = Config(FileSys.GetRawName(name))

    self.timeBeforeOffset = self.config:ReadNumber(self.configKey) or 0

    return self
end

---@param item Item
function AdjusterBefore:AddItemOffset(item)
    -- todo: check if item position < 0
    item:SetValue("D_POSITION", item:GetValue("D_POSITION") - self.timeBeforeOffset)
    item:SetValue("D_LENGTH", item:GetValue("D_LENGTH") + self.timeBeforeOffset)
    item:SetValue("D_SNAPOFFSET", self.timeBeforeOffset)

    for _, take in ipairs(item:GetTakes()) do
        if not take:TryMoveStretchMarkers(-self.timeBeforeOffset) then
            take:SetValue("D_STARTOFFS", take:GetValue("D_STARTOFFS") - self.timeBeforeOffset)
        end
    end
end

function AdjusterBefore:ProcessItems()
    local project <const> = Project(THIS_PROJECT)
    for _, item in pairs(project:GetSelectedItems()) do
        item:ClearOffset()
        self:AddItemOffset(item)
    end
end

function AdjusterBefore:ApplyOffset()
    self:Begin()
    self:ProcessItems()
    self.config:Write(self.configKey, tostring(self.timeBeforeOffset))
    self:Complete(4)
end

function AdjusterBefore:Frame()
    if self.frameCounter == 1 then
        ImGui.SetKeyboardFocusHere(self.ctx)
    end

    self.timeBeforeOffset = select(2, ImGui.InputDouble(self.ctx, "Seconds:", self.timeBeforeOffset))

    if ImGui.Button(self.ctx, "Apply") or ImGuiExt.IsEnterKeyPressed(self.ctx) then
        self:ApplyOffset()
    end
end

local scriptPath <const> = debug.getinfo(1).source

local _, filename <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = AdjusterBefore(filename, "Set item length before snap offset")

reaper.defer(function () gui:Loop() end)
