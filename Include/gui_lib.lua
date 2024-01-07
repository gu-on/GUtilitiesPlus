-- @version 1.0
-- @noindex

_INCLUDED = _INCLUDED or {}

dofile(debug.getinfo(1).source:match("@?(.*[\\|/])") .. "classic.lua")

--#region Base

GuiBase = Action:extend()

function GuiBase:new(name, undoText)
    self.name = name or nil
    self.ctx = reaper.ImGui_CreateContext(self.name) or nil
    self.font = Font(self.ctx)
    self.font:Attach()

    self.isOpen = false
    self.undoText = undoText or "NA"

    self.windowFlags = reaper.ImGui_WindowFlags_NoCollapse()
    self.windowCondition = reaper.ImGui_Cond_FirstUseEver()

    self.windowWidth = 400
    self.windowHeight = 80

    self.frameCounter = 0
end

function GuiBase:Loop()
    if self.frameCounter == 1 then
        local screenX <const>, screenY <const> = reaper.ImGui_Viewport_GetWorkCenter(reaper.ImGui_GetMainViewport(self
        .ctx))
        reaper.ImGui_SetNextWindowSize(self.ctx, self.windowWidth, self.windowHeight, self.windowCondition)
        reaper.ImGui_SetNextWindowPos(self.ctx, screenX, screenY, self.windowCondition, 0.5, 0.5)
    end

    self.font:Push()

    self.frameCounter = self.frameCounter + 1
    local isVisible <const>, isOpen <const> = reaper.ImGui_Begin(self.ctx, self.name, true, self.windowFlags)
    self.isOpen = isOpen

    if isVisible then
        self:Frame()
        reaper.ImGui_End(self.ctx)
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

function GuiBase:Complete()
    GuiBase.super.Complete(self)
    self:Close()
end

--#endregion Base

--#region FontWrapper

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

    self.ptr = reaper.ImGui_CreateFont("Arial", self.size)
end

function Font:Attach()
    if not self.ptr then return end

    reaper.ImGui_Attach(self.ctx, self.ptr)
end

function Font:Push()
    if not self.ptr and self.isPushed then return end

    reaper.ImGui_PushFont(self.ctx, self.ptr)
    self.isPushed = true
end

function Font:Pop()
    if not self.isPushed then return end

    reaper.ImGui_PopFont(self.ctx)
    self.isPushed = false
end

--#endregion FontWrapper

--#region ProgressBar

ProgressBar = GuiBase:extend()
ProgressBar.ConstHeightOffset = 38
ProgressBar.VerticalTextItems = 3

function ProgressBar:new(name)
    ProgressBar.super.new(self, name, "na")

    self.fraction = 0
    self.shouldTerminate = false

    self.windowFlags = self.windowFlags +
        reaper.ImGui_WindowFlags_AlwaysAutoResize() |
        reaper.ImGui_WindowFlags_NoScrollbar() |
        reaper.ImGui_WindowFlags_NoDocking() |
        reaper.ImGui_WindowFlags_NoMove() |
        reaper.ImGui_WindowFlags_TopMost()

    self.windowCondition = reaper.ImGui_Cond_Always()
    self.windowHeight = reaper.ImGui_GetFontSize(self.ctx) * ProgressBar.VerticalTextItems +
    ProgressBar.ConstHeightOffset
end

function ProgressBar:Frame()
    reaper.ImGui_ProgressBar(self.ctx, self.fraction)

    if reaper.ImGui_Button(self.ctx, "Cancel") then
        self:Terminate()
    end

    if not self.isOpen or not reaper.ImGui_ValidatePtr(self.ctx, "ImGui_Context*") then
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

--#endregion ProgressBar

--#region Wrappers

function reaper.ImGui_IsEnterKeyPressed(ctx)
    return
        reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false) or
        reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter(), false)
end

function reaper.ImGui_TableNext(ctx)
    reaper.ImGui_TableNextRow(ctx)
    reaper.ImGui_TableNextColumn(ctx)
end

function reaper.ImGui_TableHeader(ctx, title)
    reaper.ImGui_Text(ctx, title)
    reaper.ImGui_TableNextColumn(ctx)
end

function reaper.ImGui_TableNextColumnEntry(ctx, text, color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), color);
    reaper.ImGui_TableNextColumn(ctx);
    reaper.ImGui_Text(ctx, tostring(text));
    reaper.ImGui_PopStyleColor(ctx);
end

--#endregion Wrapers
