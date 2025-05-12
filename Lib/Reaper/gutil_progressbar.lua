-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('Reaper.gutil_gui')

---@class ProgressBar : GuiBase
---@overload fun(name: string): ProgressBar 
---@operator call: ProgressBar
ProgressBar = GuiBase:extend()

ProgressBar.ConstHeightOffset = 38
ProgressBar.VerticalTextItems = 3

function ProgressBar:new(name)
    ProgressBar.super.new(self, name, "na")

    self.fraction = 0
    self.shouldTerminate = false

    self.windowFlags = self.windowFlags +
        ImGui.WindowFlags_AlwaysAutoResize |
        ImGui.WindowFlags_NoScrollbar |
        ImGui.WindowFlags_NoDocking |
        ImGui.WindowFlags_NoMove |
        ImGui.WindowFlags_TopMost

    self.windowCondition = ImGui.Cond_Always
    self.windowHeight = ImGui.GetFontSize(self.ctx) * ProgressBar.VerticalTextItems +
    ProgressBar.ConstHeightOffset

    return self
end

function ProgressBar:Frame()
    ImGui.ProgressBar(self.ctx, self.fraction)

    if ImGui.Button(self.ctx, "Cancel") then
        self:Terminate()
    end

    if not self.isOpen or not ImGui.ValidatePtr(self.ctx, "ImGui_Context*") then
        self:Terminate()
    end

    if self.fraction >= 1 then
        self:Close()
    end
end

function ProgressBar:Terminate()
    self.shouldTerminate = true
    self:Close()
end

---@class (exact) ProgressBarManager
---@field num number
---@field denom number
---@field gui ProgressBar

return ProgressBar