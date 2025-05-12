-- @description Set item length after snap offset
-- @author guonaudio
-- @version 1.3
-- @changelog
--   Remove os lib (refactored into global)
-- @about
--   Sets the length of the item to the right of its snap offset (in seconds)

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_filesystem')
require('Reaper.gutil_config')
require('Reaper.gutil_gui')
require('Reaper.gutil_item')
require('Reaper.gutil_project')

---@class AdjusterAfter : GuiBase
---@operator call : AdjusterAfter
AdjusterAfter = GuiBase:extend()

---@param name string
---@param undoText string
function AdjusterAfter:new(name, undoText)
    AdjusterAfter.super.new(self, name, undoText)

    self.windowFlags = self.windowFlags + ImGui.WindowFlags_AlwaysAutoResize

    self.configKey = "timeAfterOffset"
    self.config = Config(FileSys.GetRawName(name))

    self.timeAfterOffset = self.config:ReadNumber(self.configKey) or 0
end

---@param item Item
function AdjusterAfter:AddItemOffset(item)
    local snapOffset <const> = item:GetValue("D_SNAPOFFSET")
    if snapOffset <= 0 then
        item:SetValue("D_LENGTH", self.timeAfterOffset)
    else
        item:SetValue("D_LENGTH", self.timeAfterOffset + snapOffset)
    end
end

function AdjusterAfter:ProcessItems()
    local project <const> = Project(THIS_PROJECT)
    local items <const> = project:GetSelectedItems()
    for _, item in pairs(items) do
        self:AddItemOffset(item)
    end
end

function AdjusterAfter:ApplyOffset()
    self:Begin()
    self:ProcessItems()
    self.config:Write(self.configKey, tostring(self.timeAfterOffset))
    self:Complete(4)
end

function AdjusterAfter:Frame()
    if self.frameCounter == 1 then
        ImGui.SetKeyboardFocusHere(self.ctx)
    end

    self.timeAfterOffset = select(2, ImGui.InputDouble(self.ctx, "Seconds:", self.timeAfterOffset))

    if ImGui.Button(self.ctx, "Apply") or ImGuiExt.IsEnterKeyPressed(self.ctx) then
        self:ApplyOffset()
    end
end

local scriptPath <const> = debug.getinfo(1).source

local _, filename <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = AdjusterAfter(filename, "Set item length after snap offset")

reaper.defer(function () gui:Loop() end)