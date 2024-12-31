-- @description Item fader
-- @author guonaudio
-- @version 1.2
-- @changelog
--   Refactor to make better use of Lua Language Server
-- @about
--   Batch fades items based on percentage of length.

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('lua.gutil_classic')
require('lua.gutil_curve')
require('lua.gutil_filesystem')
require('reaper.gutil_config')
require('reaper.gutil_gui')
require('reaper.gutil_item')
require('reaper.gutil_os')
require('reaper.gutil_project')

---@class FadeInfo : Object
---@operator call: FadeInfo
FadeInfo = Object:extend()
FadeInfo.TimerMax = 1

---@param scale number
---@param direction FadeDirection
---@param shape FadeShapeIndex
function FadeInfo:new(scale, direction, shape)
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
    self.curve.current = self.dir == 0 and self:GetCurveArrayIn(shape) or self:GetCurveArrayOut(shape)
    self.curve.previous = {}
    self.curve.next = {}

    local c <const> = Curve() ---@type Curve

    -- combo (static)
    self.linear = reaper.new_array(self.dir == 0 and c:PlotLinear() or c:PlotLinearR())
    self.fastStart = reaper.new_array(self.dir == 0 and c:PlotFastStart(2.0) or c:PlotFastStartR(2.0))
    self.fastEnd = reaper.new_array(self.dir == 0 and c:PlotFastEnd(2.0) or c:PlotFastEndR(2.0))
    self.fastStartSteep = reaper.new_array(self.dir == 0 and c:PlotFastStart(4.0) or c:PlotFastStartR(4.0))
    self.fastEndSteep = reaper.new_array(self.dir == 0 and c:PlotFastEnd(4.0) or c:PlotFastEndR(4.0))
    self.slowStartEnd = reaper.new_array(self.dir == 0 and c:PlotSlowStartEnd(2.5) or c:PlotSlowStartEndR(2.5))
    self.slowStartEndSteep = reaper.new_array(self.dir == 0 and c:PlotSlowStartEnd(7.0) or c:PlotSlowStartEndR(7.0))
end

---@param ctx ImGui_Context
function FadeInfo:Tick(ctx)
    if self.timer > FadeInfo.TimerMax then
        self.isMoving = false
        self.timer = 0
    end

    if self.isMoving then
        self.timer = self.timer + ImGui.GetDeltaTime(ctx)
        self:AnimateTransition()
    end
end

---@param ctx ImGui_Context
---@param arr reaper.array
function FadeInfo:DrawItemPlot(ctx, arr)
    ImGui.TableNextRow(ctx)
    ImGui.TableNextColumn(ctx)
    ImGui.PlotLines(ctx, "", arr, nil, nil, 0, self.scale, self.comboWidth, self.comboHeight)
end

function FadeInfo:AnimateTransition()
    local t = self.timer / FadeInfo.TimerMax
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

---@param shape FadeShapeIndex
---@return number[]
function FadeInfo:GetCurveArrayIn(shape)
    local cases <const> = {
        [0] = function() return Curve():PlotLinear() end,
        [1] = function() return Curve():PlotFastStart(2.0) end,
        [2] = function() return Curve():PlotFastEnd(2.0) end,
        [3] = function() return Curve():PlotFastStart(4.0) end,
        [4] = function() return Curve():PlotFastEnd(4.0) end,
        [5] = function() return Curve():PlotSlowStartEnd(2.5) end,
        [6] = function() return Curve():PlotSlowStartEnd(7.0) end
    } return (cases[shape] or function() return nil end)()
end

---@param shape FadeShapeIndex
---@return number[]
function FadeInfo:GetCurveArrayOut(shape)
    local cases <const> = {
        [0] = function() return Curve():PlotLinearR() end,
        [1] = function() return Curve():PlotFastStartR(2.0) end,
        [2] = function() return Curve():PlotFastEndR(2.0) end,
        [3] = function() return Curve():PlotFastStartR(4.0) end,
        [4] = function() return Curve():PlotFastEndR(4.0) end,
        [5] = function() return Curve():PlotSlowStartEndR(2.5) end,
        [6] = function() return Curve():PlotSlowStartEndR(7.0) end
    } return (cases[shape] or function() return nil end)()
end

---@param shape FadeShapeIndex
function FadeInfo:TransitionTo(shape)
    local array <const> = self.dir == 0 and self:GetCurveArrayIn(shape) or self:GetCurveArrayOut(shape)
    self:UpdateCurrentCurve(array)

    self.isMoving = true
    self.timer = 0

    self.shape = shape
end

---@param ctx ImGui_Context
function FadeInfo:DrawPreviewPlot(ctx)
    local fontSize <const> = ImGui.GetFontSize(ctx)
    local width <const> = ImGui.GetWindowWidth(ctx) * 0.5 - self.constWidthOffset
    local height <const> = ImGui.GetWindowHeight(ctx) - fontSize * 4.0 - self.constHeightOffset

    local array <const> = reaper.new_array(self.curve.current)
    ImGui.PlotLines(ctx, "", array, nil, nil, 0, self.scale, width, height)
end

---@param index FadeShapeIndex
---@return reaper.array|nil
function FadeInfo:GetPlot(index)
    local cases <const> = {
        [0] = function() return self.linear end,
        [1] = function() return self.fastStart end,
        [2] = function() return self.fastEnd end,
        [3] = function() return self.fastStartSteep end,
        [4] = function() return self.fastEndSteep end,
        [5] = function() return self.slowStartEnd end,
        [6] = function() return self.slowStartEndSteep end,
    } return (cases[index] or function() return nil end)()
end

---@param index FadeShapeIndex
---@return string
function FadeInfo.GetName(index)
    local cases <const> = {
        [0] = function() return "linear" end,
        [1] = function() return "fastStart" end,
        [2] = function() return "fastEnd" end,
        [3] = function() return "fastStartSteep" end,
        [4] = function() return "fastEndSteep" end,
        [5] = function() return "slowStartEnd" end,
        [6] = function() return "slowStartEndSteep" end,
    } return (cases[index] or function() return nil end)()
end

---@param ctx ImGui_Context
---@param shape FadeShapeIndex
function FadeInfo:DrawPlot(ctx, shape)
    local plot <const> = self:GetPlot(shape)
    if plot then
        self:DrawItemPlot(ctx, plot)
    end
end

---@class ItemFader : GuiBase
---@operator call: ItemFader
ItemFader = GuiBase:extend()

ItemFader.RegColor = 0x1D2F49f2
ItemFader.HoverColor = 0x335c96f2
ItemFader.SliderMin = 0
ItemFader.SliderMax = 100
ItemFader.FadeShapeMax = 7

function ItemFader:new(name, undoText)
    ItemFader.super.new(self, name, undoText)

    -- project
    self.lastProjectState = nil
    self.project = Project(THIS_PROJECT)
    self.items = self.project:GetSelectedItems()
    self.highlightIndex = 0

    -- processing
    self.fadeInRatio = self:GetItemFadeInAverage()
    self.fadeOutRatio = self:GetItemFadeOutAverage()

    -- config
    self.config = Config(FileSys.GetRawName(name))
    self.configKeyCurveIn = "fadeCurveIn"
    self.configKeyCurveOut = "fadeCurveOut"

    --todo: clamp
    local fadeShapeIn <const> = self.config:ReadNumber(self.configKeyCurveIn) or 0 ---@cast fadeShapeIn FadeShapeIndex
    local fadeShapeOut <const> = self.config:ReadNumber(self.configKeyCurveOut) or 0 ---@cast fadeShapeOut FadeShapeIndex

    -- fadeInfo
    self.fadeIn = FadeInfo(32, 0, fadeShapeIn)
    self.fadeOut = FadeInfo(32, 1, fadeShapeOut)

    self.fadeIn:TransitionTo(fadeShapeIn)
    self.fadeOut:TransitionTo(fadeShapeOut)

    -- gui
    self.windowWidth = 460
    self.windowHeight = 250

    self:Begin()
end

function ItemFader:OnClose()
    self:Complete(4)
end

function ItemFader:GetItemFadeInAverage()
    local items <const> = self.project:GetSelectedItems()
    local totalAverage = 0
    for _, item in ipairs(items) do
        totalAverage = totalAverage + (item:GetValue("D_FADEINLEN") / item:GetValue("D_LENGTH") * 100)
    end
    return #items > 0 and totalAverage / #items or ItemFader.SliderMin
end

function ItemFader:GetItemFadeOutAverage()
    local items <const> = self.project:GetSelectedItems()
    local totalAverage = 0
    for _, item in ipairs(items) do
        totalAverage = totalAverage + (item:GetValue("D_FADEOUTLEN") / item:GetValue("D_LENGTH") * 100)
    end
    return #items > 0 and 100 - (totalAverage / #items) or ItemFader.SliderMax
end

function ItemFader:FadeSelectedItemsIn()
    for _, item in ipairs(self.items) do
        item:SetValue("D_FADEINLEN", item:GetValue("D_LENGTH") * self.fadeInRatio * 0.01)
        item:SetValue("C_FADEINSHAPE", self.fadeIn.shape)
    end
    reaper.UpdateArrange()
end

function ItemFader:FadeSelectedItemsOut()
    for _, item in ipairs(self.items) do
        item:SetValue("D_FADEOUTLEN", item:GetValue("D_LENGTH") * (ItemFader.SliderMax - self.fadeOutRatio) * 0.01)
        item:SetValue("C_FADEOUTSHAPE", self.fadeOut.shape)
    end
    reaper.UpdateArrange()
end

function ItemFader:IsSliderInput()
    return ImGui.IsItemActive(self.ctx) and ImGui.IsMouseDown(self.ctx, 0)
end

function ItemFader:IsTypedInput()
    return ImGui.IsItemFocused(self.ctx) and ImGuiExt.IsEnterKeyPressed(self.ctx)
end

function ItemFader:GetScrollValueIfHovered()
    if not ImGui.IsItemHovered(self.ctx) then return 0 end
    return math.floor(ImGui.GetMouseWheel(self.ctx))
end

function ItemFader:DrawFadeInRatioSlider()
    ImGui.PushID(self.ctx, "FadeInRatio")
    _, self.fadeInRatio =
        ImGui.SliderDouble(self.ctx, "Ratio: ", self.fadeInRatio, ItemFader.SliderMin, ItemFader.SliderMax,
            "%06.2f",
            ImGui.SliderFlags_AlwaysClamp)
    ImGui.PopID(self.ctx)

    if self:IsSliderInput() then
        self:FadeSelectedItemsIn()
    end

    if self.fadeInRatio > self.fadeOutRatio then
        self.fadeInRatio = self.fadeOutRatio
        self:FadeSelectedItemsIn()
    end

    local value = self:GetScrollValueIfHovered()
    if value ~= 0 then
        self.fadeInRatio = Maths.Clamp(self.fadeInRatio + value, ItemFader.SliderMin, ItemFader.SliderMax)
        self:FadeSelectedItemsIn()
    end
end

--- FadeOutRatio is reversed to visualize a fade as percentage from item's right-edge
--- This is implemented by subtracting ratio from SLIDER_MAX (100.0)
function ItemFader:DrawFadeOutRatioSlider()
    local display <const> = ItemFader.SliderMax - self.fadeOutRatio
    ImGui.PushID(self.ctx, "FadeOutRatio")
    _, self.fadeOutRatio =
        ImGui.SliderDouble(self.ctx, "Ratio: ", self.fadeOutRatio, ItemFader.SliderMin, ItemFader.SliderMax,
            string.format("%06.2f", display),
            ImGui.SliderFlags_AlwaysClamp)
    ImGui.PopID(self.ctx)

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

    local value = self:GetScrollValueIfHovered()
    if value ~= 0 then
        self.fadeOutRatio = Maths.Clamp(self.fadeOutRatio + value, ItemFader.SliderMin, ItemFader.SliderMax)
        self:FadeSelectedItemsOut()
    end
end

---@param info FadeInfo
---@param shape FadeShapeIndex
function ItemFader:SaveConfigFile(info, shape)
    self.config:Write(info.dir == 0 and self.configKeyCurveIn or self.configKeyCurveOut, tostring(shape))
end

---@param info FadeInfo
---@param shape FadeShapeIndex
function ItemFader:Transition(info, shape)
    info:TransitionTo(shape)
    self:SaveConfigFile(info, shape)
    if info.dir == 0 then
        self:FadeSelectedItemsIn()
    else
        self:FadeSelectedItemsOut()
    end
end

---@param info FadeInfo
---@param shape FadeShapeIndex
function ItemFader:DrawStaticCurve(info, shape)
    ImGui.PushStyleColor(self.ctx, ImGui.Col_FrameBg, self.highlightIndex == shape and self.HoverColor or self.RegColor)
    info:DrawPlot(self.ctx, shape)
    ImGui.PopStyleColor(self.ctx)

    if ImGui.IsItemHovered(self.ctx) then self.highlightIndex = shape end
    if ImGui.IsItemClicked(self.ctx) then self:Transition(info, shape) end
end

---@param info FadeInfo
---@param id string
function ItemFader:DrawCurvesCombo(info, id)
    ImGui.SetNextItemWidth(self.ctx, ImGui.GetWindowWidth(self.ctx) * 0.5 - 18) -- 18 is a constant width offset

    ImGui.PushID(self.ctx, id)
    ImGui.PushStyleColor(self.ctx, ImGui.Col_PopupBg, 0x00000000)
    ImGui.PushStyleColor(self.ctx, ImGui.Col_Border, 0x00000000);

    if ImGui.BeginCombo(self.ctx, "", FadeInfo.GetName(info.shape), ImGui.ComboFlags_HeightLargest) then
        ImGui.PushStyleColor(self.ctx, ImGui.Col_Text, 0xffffff00);
        ImGui.PushStyleColor(self.ctx, ImGui.Col_TableBorderStrong, 0xffffffff);
        if ImGui.BeginTable(self.ctx, "table", 1, ImGui.TableFlags_Borders, 110) then -- 110 is constant table width
            self:DrawStaticCurve(info, 0)
            self:DrawStaticCurve(info, 1)
            self:DrawStaticCurve(info, 2)
            self:DrawStaticCurve(info, 3)
            self:DrawStaticCurve(info, 4)
            self:DrawStaticCurve(info, 5)
            self:DrawStaticCurve(info, 6)

            ImGui.PopStyleColor(self.ctx, 2)
            ImGui.EndTable(self.ctx)
        end
        ImGui.EndCombo(self.ctx)
    end

    ImGui.PopStyleColor(self.ctx, 2)
    ImGui.PopID(self.ctx)
    ImGui.Spacing(self.ctx)

    self:HandleHoverScrollTransition(info)
end

---@param info FadeInfo
function ItemFader:HandleHoverScrollTransition(info)
    local value <const> = self:GetScrollValueIfHovered()
    if value == 0 then return end

    local next <const> = info.shape - value
    if next >= 0 and next < ItemFader.FadeShapeMax  then
        self:Transition(info, next)
    end
end

function ItemFader:Frame()
    local latestState <const> = reaper.GetProjectStateChangeCount(THIS_PROJECT)
    if self.lastProjectState ~= latestState then
        self.lastProjectState = latestState
        self.items = self.project:GetSelectedItems()
    end

    self.fadeIn:Tick(self.ctx)
    self.fadeOut:Tick(self.ctx)

    if ImGui.BeginTable(self.ctx, "table", 2, ImGui.TableFlags_Borders) then
        -- table setup
        ImGui.TableSetupColumn(self.ctx, "Fade In")
        ImGui.TableSetupColumn(self.ctx, "Fade Out")

        ImGui.TableHeadersRow(self.ctx)
        ImGui.TableNextRow(self.ctx)

        -- fade in display
        ImGui.TableSetColumnIndex(self.ctx, 0)

        ImGui.Spacing(self.ctx)
        self.fadeIn:DrawPreviewPlot(self.ctx)
        self:HandleHoverScrollTransition(self.fadeIn)

        self:DrawFadeInRatioSlider()

        self:DrawCurvesCombo(self.fadeIn, "FadeIn")

        -- fade out display
        ImGui.TableSetColumnIndex(self.ctx, 1)

        ImGui.Spacing(self.ctx)
        self.fadeOut:DrawPreviewPlot(self.ctx)
        self:HandleHoverScrollTransition(self.fadeOut)

        self:DrawFadeOutRatioSlider()

        self:DrawCurvesCombo(self.fadeOut, "FadeOut")

        ImGui.EndTable(self.ctx)
    end

    if ImGuiExt.IsEnterKeyPressed(self.ctx) then
        self:Close()
    end
end

--#endregion

local scriptPath <const> = debug.getinfo(1).source

local _, scriptName <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = ItemFader(scriptName, "Apply fade to selected items")

reaper.defer(function () gui:Loop() end)