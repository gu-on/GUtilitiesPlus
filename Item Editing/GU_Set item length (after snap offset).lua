-- @description Set item length after snap offset
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Sets the length of the item to the right of its snap offset (in seconds)

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/gui_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")

AdjusterAfter = GuiBase:extend()

function AdjusterAfter:new(name, undoText)
    AdjusterAfter.super.new(self, name, undoText)

    self.windowFlags = self.windowFlags + reaper.ImGui_WindowFlags_AlwaysAutoResize()

    self.configKey = "timeAfterOffset"
    self.config = Config(FileSys.GetRawName(name))

    local rv <const> = self.config:Read(self.configKey)
    self.timeAfterOffset = tonumber(rv) or 0
end

function AdjusterAfter:AddItemOffset(item)
    local snapOffset <const> = item:GetSnapOffset()
    if snapOffset <= 0 then
        item:SetLength(self.timeAfterOffset)
    else
        item:SetLength(self.timeAfterOffset + snapOffset)
    end
end

function AdjusterAfter:ProcessItems()
    local items <const> = Items(FillType.Selected)
    for _, item in pairs(items.array) do
        self:AddItemOffset(item)
    end
end

function AdjusterAfter:ApplyOffset()
    self:Begin()
    self:ProcessItems()
    self.config:Write(self.configKey, tostring(self.timeAfterOffset))
    self:Complete(reaper.UndoState.Items)
end

function AdjusterAfter:Frame()
    if self.frameCounter == 1 then
        reaper.ImGui_SetKeyboardFocusHere(self.ctx)
    end

    local _, v = reaper.ImGui_InputDouble(self.ctx, "Seconds:", self.timeAfterOffset)
    self.timeAfterOffset = v

    if reaper.ImGui_Button(self.ctx, "Apply") or reaper.ImGui_IsEnterKeyPressed(self.ctx) then
        self:ApplyOffset()
    end
end

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = AdjusterAfter(file, "Set item length after snap offset")

reaper.defer(function() gui:Loop() end)
