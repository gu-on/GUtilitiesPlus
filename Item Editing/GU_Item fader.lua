-- @description Item fader
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Batch fades items based on percentage of length.

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/gui_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")

--#region FadeInfo

FadeInfo = Object:extend()
FadeInfo.TIMER_MAX = 1

function FadeInfo:new(scale, direction, fadeShape)
    -- animation
    self.timer = 0
    self.isMoving = false
    self.scale = scale or 32
    self.shape = 1
    self.dir = direction or 0

    -- gui
    self.constWidthOffset = 18
    self.constHeightOffset = 58
    self.comboWidth = 100.0
    self.comboHeight = 50.0

    -- preview
    self.curve = {}
    self.curve.current = self:GetCurveArray(fadeShape)
    self.curve.previous = {}
    self.curve.next = {}

    -- combo (static)
    self.linear =
        reaper.new_array(self.dir == FadeDirection.In and Curve():PlotLinear() or Curve():PlotLinearR())
    self.fastStart =
        reaper.new_array(self.dir == FadeDirection.In and Curve():PlotFastStart(2.0) or Curve():PlotFastStartR(2.0))
    self.fastEnd =
        reaper.new_array(self.dir == FadeDirection.In and Curve():PlotFastEnd(2.0) or Curve():PlotFastEndR(2.0))
    self.fastStartSteep =
        reaper.new_array(self.dir == FadeDirection.In and Curve():PlotFastStart(4.0) or Curve():PlotFastStartR(4.0))
    self.fastEndSteep =
        reaper.new_array(self.dir == FadeDirection.In and Curve():PlotFastEnd(4.0) or Curve():PlotFastEndR(4.0))
    self.slowStartEnd =
        reaper.new_array(self.dir == FadeDirection.In and Curve():PlotSlowStartEnd(2.5) or Curve():PlotSlowStartEndR(2.5))
    self.slowStartEndSteep =
        reaper.new_array(self.dir == FadeDirection.In and Curve():PlotSlowStartEnd(7.0) or Curve():PlotSlowStartEndR(7.0))
end

function FadeInfo:Tick(ctx)
    if self.timer > FadeInfo.TIMER_MAX then
        self.isMoving = false
        self.timer = 0
    end

    if self.isMoving then
        self.timer = self.timer + reaper.ImGui_GetDeltaTime(ctx)
        self:AnimateTransition()
    end
end

function FadeInfo:DrawItemPlot(ctx, arr)
    reaper.ImGui_TableNextRow(ctx)
    reaper.ImGui_TableNextColumn(ctx)
    reaper.ImGui_PlotLines(ctx, "", arr, nil, nil, 0, self.scale, self.comboWidth, self.comboHeight)
end

function FadeInfo:AnimateTransition()
    local t = self.timer / FadeInfo.TIMER_MAX
    for i, _ in ipairs(self.curve.current) do
        self.curve.current[i] = Maths.Clamp(
            self.curve.previous[i] +
            (self.curve.next[i] - self.curve.previous[i]) * Maths.EaseOutBounce(t), 0.0, self.scale)
    end
end

function FadeInfo:UpdateCurrentCurve(array)
    for i, v in ipairs(self.curve.current) do
        self.curve.previous[i] = v
    end

    for i, v in ipairs(array) do
        self.curve.next[i] = v
    end
end

function FadeInfo:GetCurveArray(fadeShape)
    local array = {}
    if fadeShape == FadeShape.fastStart then
        array = self.dir == FadeDirection.In and Curve():PlotFastStart(2.0) or Curve():PlotFastStartR(2.0)
    elseif fadeShape == FadeShape.fastEnd then
        array = self.dir == FadeDirection.In and Curve():PlotFastEnd(2.0) or Curve():PlotFastEndR(2.0)
    elseif fadeShape == FadeShape.fastStartSteep then
        array = self.dir == FadeDirection.In and Curve():PlotFastStart(4.0) or Curve():PlotFastStartR(4.0)
    elseif fadeShape == FadeShape.fastEndSteep then
        array = self.dir == FadeDirection.In and Curve():PlotFastEnd(4.0) or Curve():PlotFastEndR(4.0)
    elseif fadeShape == FadeShape.slowStartEnd then
        array = self.dir == FadeDirection.In and Curve():PlotSlowStartEnd(2.5) or Curve():PlotSlowStartEndR(2.5)
    elseif fadeShape == FadeShape.slowStartEndSteep then
        array = self.dir == FadeDirection.In and Curve():PlotSlowStartEnd(7.0) or Curve():PlotSlowStartEndR(7.0)
    else
        array = self.dir == FadeDirection.In and Curve():PlotLinear() or Curve():PlotLinearR()
    end
    return array
end

function FadeInfo:TransitionTo(fadeShape)
    local array = self:GetCurveArray(fadeShape)
    self:UpdateCurrentCurve(array)

    self.isMoving = true
    self.timer = 0

    self.shape = fadeShape
end

function FadeInfo:DrawPreviewPlot(ctx)
    local fontSize = reaper.ImGui_GetFontSize(ctx)
    local width = reaper.ImGui_GetWindowWidth(ctx) * 0.5 - self.constWidthOffset
    local height = reaper.ImGui_GetWindowHeight(ctx) - fontSize * 4.0 - self.constHeightOffset

    local array = reaper.new_array(self.curve.current)
    reaper.ImGui_PlotLines(ctx, "", array, nil, nil, 0, self.scale, width, height)
end

function FadeInfo:DrawPlot(ctx, fadeShape)
    if fadeShape == FadeShape.linear then
        self:DrawLinear(ctx)
    elseif fadeShape == FadeShape.fastStart then
        self:DrawFastStart(ctx)
    elseif fadeShape == FadeShape.fastEnd then
        self:DrawFastEnd(ctx)
    elseif fadeShape == FadeShape.fastStartSteep then
        self:DrawFastStartSteep(ctx)
    elseif fadeShape == FadeShape.fastEndSteep then
        self:DrawFastEndSteep(ctx)
    elseif fadeShape == FadeShape.slowStartEnd then
        self:DrawSlowStartEnd(ctx)
    elseif fadeShape == FadeShape.slowStartEndSteep then
        self:DrawSlowStartEndSteep(ctx)
    else
        Debug:Log("FadeInfo:DrawPlot() Out of bounds")
    end
end

function FadeInfo:DrawLinear(ctx) self:DrawItemPlot(ctx, self.linear) end

function FadeInfo:DrawFastStart(ctx) self:DrawItemPlot(ctx, self.fastStart) end

function FadeInfo:DrawFastEnd(ctx) self:DrawItemPlot(ctx, self.fastEnd) end

function FadeInfo:DrawFastStartSteep(ctx) self:DrawItemPlot(ctx, self.fastStartSteep) end

function FadeInfo:DrawFastEndSteep(ctx) self:DrawItemPlot(ctx, self.fastEndSteep) end

function FadeInfo:DrawSlowStartEnd(ctx) self:DrawItemPlot(ctx, self.slowStartEnd) end

function FadeInfo:DrawSlowStartEndSteep(ctx) self:DrawItemPlot(ctx, self.slowStartEndSteep) end

--#endregion

--#region ItemFader

ItemFader = GuiBase:extend()
ItemFader.regularCol = 0x1D2F49f2
ItemFader.hoverCol = 0x335c96f2
ItemFader.SLIDER_MIN = 0
ItemFader.SLIDER_MAX = 100

function ItemFader:new(name, undoText)
    ItemFader.super.new(self, name, undoText)

    -- project
    self.lastProjectState = nil
    self.items = Items(FillType.Selected)
    self.highlightIndex = 0

    -- processing
    self.fadeInRatio = self:GetItemFadeInAverage()
    self.fadeOutRatio = self:GetItemFadeOutAverage()

    -- config
    self.configKeyCurveIn = "fadeCurveIn"
    self.configKeyCurveOut = "fadeCurveOut"
    self.config = Config(FileSys.GetRawName(name))

    local fadeShapeIn <const> = tonumber(self.config:Read(self.configKeyCurveIn)) or 0
    -- set in curve
    local fadeShapeOut <const> = tonumber(self.config:Read(self.configKeyCurveOut)) or 0
    -- set out curve

    -- fadeInfo
    self.fadeIn = FadeInfo(32, FadeDirection.In, fadeShapeIn)
    self.fadeOut = FadeInfo(32, FadeDirection.Out, fadeShapeOut)

    self.fadeIn:TransitionTo(fadeShapeIn)
    self.fadeOut:TransitionTo(fadeShapeOut)

    -- gui
    self.windowWidth = 460
    self.windowHeight = 250

    self:Begin()
end

function ItemFader:OnClose()
    self:Complete(reaper.UndoState.Items)
end

function ItemFader:GetItemFadeInAverage()
    local items <const> = Items(FillType.Selected)
    local totalAverage = 0
    for _, item in ipairs(items.array) do
        totalAverage = totalAverage + (item:GetFadeInLength() / item:GetLength() * 100)
    end
    local totalCount <const> = items:Size()
    return totalCount > 0 and totalAverage / totalCount or ItemFader.SLIDER_MIN
end

function ItemFader:GetItemFadeOutAverage()
    local items <const> = Items(FillType.Selected)
    local totalAverage = 0
    for _, item in ipairs(items.array) do
        totalAverage = totalAverage + (item:GetFadeOutLength() / item:GetLength() * 100)
    end
    local totalCount <const> = items:Size()
    return totalCount > 0 and 100 - (totalAverage / totalCount) or ItemFader.SLIDER_MAX
end

function ItemFader:FadeSelectedItemsIn()
    for _, item in ipairs(self.items.array) do
        item:SetFadeInLength(item:GetLength() * self.fadeInRatio * 0.01)
        item:SetFadeInShape(self.fadeIn.shape)
    end
    reaper.UpdateArrange()
end

function ItemFader:FadeSelectedItemsOut()
    for _, item in ipairs(self.items.array) do
        item:SetFadeOutLength(item:GetLength() * (ItemFader.SLIDER_MAX - self.fadeOutRatio) * 0.01)
        item:SetFadeOutShape(self.fadeOut.shape)
    end
    reaper.UpdateArrange()
end

function ItemFader:IsSliderInput()
    return reaper.ImGui_IsItemActive(self.ctx) and reaper.ImGui_IsMouseDown(self.ctx, 0)
end

function ItemFader:IsTypedInput()
    return reaper.ImGui_IsItemFocused(self.ctx) and reaper.ImGui_IsEnterKeyPressed(self.ctx)
end

function ItemFader:DrawFadeInRatioSlider()
    reaper.ImGui_PushID(self.ctx, "FadeInRatio")
    _, self.fadeInRatio =
        reaper.ImGui_SliderDouble(self.ctx, "Ratio: ", self.fadeInRatio, ItemFader.SLIDER_MIN, ItemFader.SLIDER_MAX,
            "%06.2f",
            reaper.ImGui_SliderFlags_AlwaysClamp())
    reaper.ImGui_PopID(self.ctx)

    if self:IsSliderInput() then
        self:FadeSelectedItemsIn()
    end

    if self.fadeInRatio > self.fadeOutRatio then
        self.fadeInRatio = self.fadeOutRatio
        self:FadeSelectedItemsIn()
    end
end

-- FadeOutRatio is reversed to visualize a fade as percentage from item's right-edge
-- This is implemented by subtracting ratio from SLIDER_MAX (100.0)
function ItemFader:DrawFadeOutRatioSlider()
    local display <const> = ItemFader.SLIDER_MAX - self.fadeOutRatio
    reaper.ImGui_PushID(self.ctx, "FadeOutRatio")
    _, self.fadeOutRatio =
        reaper.ImGui_SliderDouble(self.ctx, "Ratio: ", self.fadeOutRatio, ItemFader.SLIDER_MIN, ItemFader.SLIDER_MAX,
            string.format("%06.2f", display),
            reaper.ImGui_SliderFlags_AlwaysClamp())
    reaper.ImGui_PopID(self.ctx)

    if self:IsSliderInput() then
        self:FadeSelectedItemsOut()
    elseif self:IsTypedInput() then
        self.fadeOutRatio = 100 - self.fadeOutRatio -- UX feature to reverse slider
        self:FadeSelectedItemsOut()
    end

    if self.fadeOutRatio < self.fadeInRatio then
        self.fadeOutRatio = self.fadeInRatio
        self:FadeSelectedItemsOut()
    end
end

function ItemFader:SaveConfigFile(fadeInfo, fadeShape)
    if fadeInfo.dir == FadeDirection.In then
        self.config:Write(self.configKeyCurveIn, tostring(fadeShape))
    else
        self.config:Write(self.configKeyCurveOut, tostring(fadeShape))
    end
end

function ItemFader:Transition(fadeInfo, fadeShape)
    fadeInfo:TransitionTo(fadeShape)
    self:SaveConfigFile(fadeInfo, fadeShape)
    if fadeInfo.dir == FadeDirection.In then
        self:FadeSelectedItemsIn()
    else
        self:FadeSelectedItemsOut()
    end
end

function ItemFader:DrawStaticCurve(fadeInfo, fadeshape)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBg(),
        self.highlightIndex == fadeshape and self.hoverCol or self.regularCol)
    fadeInfo:DrawPlot(self.ctx, fadeshape)
    reaper.ImGui_PopStyleColor(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx) then self.highlightIndex = fadeshape end
    if reaper.ImGui_IsItemClicked(self.ctx) then self:Transition(fadeInfo, fadeshape) end
end

function ItemFader:DrawCurvesCombo(fadeInfo, idStr)
    reaper.ImGui_SetNextItemWidth(self.ctx, reaper.ImGui_GetWindowWidth(self.ctx) * 0.5 - 18) -- 18 is a constant width offset

    reaper.ImGui_PushID(self.ctx, idStr)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_PopupBg(), 0x00000000)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Border(), 0x00000000);

    if reaper.ImGui_BeginCombo(self.ctx, "", FadeShape.GetName(fadeInfo.shape), reaper.ImGui_ComboFlags_HeightLargest()) then
        reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Text(), 0xffffff00);
        reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_TableBorderStrong(), 0xffffffff);
        if reaper.ImGui_BeginTable(self.ctx, "table", 1, reaper.ImGui_TableFlags_Borders(), 110) then -- 110 is constant table width
            self:DrawStaticCurve(fadeInfo, FadeShape.linear)
            self:DrawStaticCurve(fadeInfo, FadeShape.fastStart)
            self:DrawStaticCurve(fadeInfo, FadeShape.fastEnd)
            self:DrawStaticCurve(fadeInfo, FadeShape.fastStartSteep)
            self:DrawStaticCurve(fadeInfo, FadeShape.fastEndSteep)
            self:DrawStaticCurve(fadeInfo, FadeShape.slowStartEnd)
            self:DrawStaticCurve(fadeInfo, FadeShape.slowStartEndSteep)

            reaper.ImGui_PopStyleColor(self.ctx, 2)
            reaper.ImGui_EndTable(self.ctx)
        end
        reaper.ImGui_EndCombo(self.ctx)
    end

    reaper.ImGui_PopStyleColor(self.ctx, 2)
    reaper.ImGui_PopID(self.ctx)
    reaper.ImGui_Spacing(self.ctx)
end

function ItemFader:Frame()
    local latestState <const> = reaper.GetProjectStateChangeCount(THIS_PROJECT)
    if self.lastProjectState ~= latestState then
        self.lastProjectState = latestState
        self.items:FillSelected()
    end

    self.fadeIn:Tick(self.ctx)
    self.fadeOut:Tick(self.ctx)

    if reaper.ImGui_BeginTable(self.ctx, "table", 2, reaper.ImGui_TableFlags_Borders()) then
        -- table setup
        reaper.ImGui_TableSetupColumn(self.ctx, "Fade In")
        reaper.ImGui_TableSetupColumn(self.ctx, "Fade Out")

        reaper.ImGui_TableHeadersRow(self.ctx)
        reaper.ImGui_TableNextRow(self.ctx)

        -- fade in display
        reaper.ImGui_TableSetColumnIndex(self.ctx, 0)

        reaper.ImGui_Spacing(self.ctx)
        self.fadeIn:DrawPreviewPlot(self.ctx)

        self:DrawFadeInRatioSlider()

        self:DrawCurvesCombo(self.fadeIn, "FadeIn");

        -- fade out display
        reaper.ImGui_TableSetColumnIndex(self.ctx, 1)

        reaper.ImGui_Spacing(self.ctx)
        self.fadeOut:DrawPreviewPlot(self.ctx)

        self:DrawFadeOutRatioSlider()

        self:DrawCurvesCombo(self.fadeOut, "FadeOut");

        reaper.ImGui_EndTable(self.ctx)
    end

    if reaper.ImGui_IsEnterKeyPressed(self.ctx) then
        self:Close()
    end
end

--#endregion

local _, scriptName <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = ItemFader(scriptName, "Apply fade to selected items")

reaper.defer(function () gui:Loop() end)
