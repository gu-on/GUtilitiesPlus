-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('Lua.gutil_classic')
require('Reaper.gutil_action')

package.path = package.path .. ";" .. reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9'

---@class GuiBase : Object, Action
---@operator call: GuiBase
GuiBase = Object:extend()
GuiBase:implement(Action)

---@param name string
---@param undoText string
function GuiBase:new(name, undoText)
    self.name = name or ""
    self.ctx = ImGui.CreateContext(self.name) or nil
    self.font = Font(self.ctx)
    self.font:Attach()

    self.isOpen = false
    self.undoText = undoText or "NA"

    self.windowFlags = ImGui.WindowFlags_NoCollapse
    self.windowCondition = ImGui.Cond_FirstUseEver

    self.windowWidth = 400
    self.windowHeight = 80

    self.frameCounter = 0
end

function GuiBase:Loop()
    if self.frameCounter == 1 then
        local screenX <const>, screenY <const> = ImGui.Viewport_GetWorkCenter(ImGui.GetMainViewport(self
        .ctx))
        ImGui.SetNextWindowSize(self.ctx, self.windowWidth, self.windowHeight, self.windowCondition)
        ImGui.SetNextWindowPos(self.ctx, screenX, screenY, self.windowCondition, 0.5, 0.5)
    end

    self.font:Push()

    self.frameCounter = self.frameCounter + 1
    local isVisible <const>, isOpen <const> = ImGui.Begin(self.ctx, self.name, true, self.windowFlags)
    self.isOpen = isOpen

    if isVisible then
        self:Frame()
        ImGui.End(self.ctx)
    end

    self.font:Pop()

    if self.isOpen then
        reaper.defer(function () self:Loop() end)
    else
        self:OnClose()
    end
end

function GuiBase:Frame()
    error("to be inherited")
end

function GuiBase:OnClose()
    -- to be inherited
end

function GuiBase:Close()
    self.isOpen = false
end

---@classic Font : Object
Font = Object:extend()

Font.SizeMin = 10
Font.SizeMax = 36

function Font:new(ctx)
    self.ctx = ctx
    self.size = 14
    local success <const>, value <const> = reaper.GU_Config_Read("GUtilities", "UserConfig", "fontSize")

    if not success or value == "" then return end

    self.size = Maths.Clamp(tonumber(value), Font.SizeMin, Font.SizeMax)

    if self.size % 2 ~= 0 then self.size = self.size + 1 end -- even numbers look better

    self.ptr = ImGui.CreateFont("Arial", self.size)
end

function Font:Attach()
    if not self.ptr then return end

    ImGui.Attach(self.ctx, self.ptr)
end

function Font:Push()
    if not self.ptr and self.isPushed then return end

    ImGui.PushFont(self.ctx, self.ptr)
    self.isPushed = true
end

function Font:Pop()
    if not self.isPushed then return end

    ImGui.PopFont(self.ctx)
    self.isPushed = false
end

---@class ImGuiExt
ImGuiExt = {}

---@param ctx ImGui_Context
---@return boolean
function ImGuiExt.IsEnterKeyPressed(ctx)
    return
        ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false) or
        ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter, false)
end

---@param ctx ImGui_Context
function ImGuiExt.TableNext(ctx)
    ImGui.TableNextRow(ctx)
    ImGui.TableNextColumn(ctx)
end

---@param ctx ImGui_Context
---@param title string
function ImGuiExt.TableHeading(ctx, title)
    ImGui.Text(ctx, title)
    ImGui.TableNextColumn(ctx)
end

---@param ctx ImGui_Context
---@param text string
---@param color integer
function ImGuiExt.TableNextColumnEntry(ctx, text, color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, color);
    ImGui.TableNextColumn(ctx);
    ImGui.Text(ctx, tostring(text));
    ImGui.PopStyleColor(ctx);
end