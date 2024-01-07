-- @description Set item length before snap offset
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Sets the length of the item to the left of its snap offset (in seconds)

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/gui_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")

AdjusterBefore = GuiBase:extend()

function AdjusterBefore:new(name, undoText)
    AdjusterBefore.super.new(self, name, undoText)

    self.windowFlags = self.windowFlags + reaper.ImGui_WindowFlags_AlwaysAutoResize()

    self.configKey = "timeBeforeOffset"
    self.config = Config(FileSys.GetRawName(name))

    local rv <const> = self.config:Read(self.configKey)
    self.timeBeforeOffset = tonumber(rv) or 0
end

function AdjusterBefore:AddItemOffset(item)
    item:SetPosition(item:GetStart() - self.timeBeforeOffset)
    item:SetLength(item:GetLength() + self.timeBeforeOffset)
    item:SetSnapOffset(self.timeBeforeOffset)

    for _, take in pairs(item:GetTakes()) do
        take:SetStartOffset(take:GetStartOffset() - self.timeBeforeOffset)
    end
end

function AdjusterBefore:ProcessItems()
    local items <const> = Items(FillType.Selected)
    for _, item in pairs(items.array) do
        item:ClearOffset()
        self:AddItemOffset(item)
    end
end

function AdjusterBefore:ApplyOffset()
    self:Begin()
    self:ProcessItems()
    self.config:Write(self.configKey, tostring(self.timeBeforeOffset))
    self:Complete(reaper.UndoState.Items)
end

function AdjusterBefore:Frame()
    if self.frameCounter == 1 then
        reaper.ImGui_SetKeyboardFocusHere(self.ctx)
    end

    local _, v <const> = reaper.ImGui_InputDouble(self.ctx, "Seconds:", self.timeBeforeOffset)
    self.timeBeforeOffset = v

    if reaper.ImGui_Button(self.ctx, "Apply") or reaper.ImGui_IsEnterKeyPressed(self.ctx) then
        self:ApplyOffset()
    end
end

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = AdjusterBefore(file, "Set item length before snap offset")

reaper.defer(function() gui:Loop() end)
