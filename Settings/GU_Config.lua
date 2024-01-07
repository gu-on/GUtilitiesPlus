-- @description GUtilities scripts config
-- @author guonaudio
-- @version 1.0
-- @provides
--   [nomain]../Include/classic.lua
--   [nomain]../Include/gui_lib.lua
--   [nomain]../Include/reaper_lib.lua
--   [nomain]../Include/sourcevalidator_lib.lua
--   [nomain]../Include/utils_lib.lua
-- @changelog
--   Initial release
-- @about
--   Provides global settings for GUtilities Scripts
--   This script must be included by ReaPack to ensure all libraries are donwloaded

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/gui_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")

local UserConfig <const> = GuiBase:extend();

UserConfig.MinFontSize = 10
UserConfig.MaxFontSize = 36

function UserConfig:new(name)
    UserConfig.super.new(self, name, "NA")

    self.configKeyFontSize = "fontSize"
    self.config = Config("UserConfig")

    self.fontSize = self.config:Read(self.configKeyFontSize) or 14
end

function UserConfig:Frame()
    if reaper.ImGui_CollapsingHeader(self.ctx, "General") then
        if reaper.ImGui_TreeNode(self.ctx, "Font") then
            _, self.fontSize = reaper.ImGui_InputInt(self.ctx, "Font Size", self.fontSize)

            if reaper.ImGui_IsItemHovered(self.ctx) then
                reaper.ImGui_SetTooltip(self.ctx, "Open & close running windows to refresh font size")
            end

            self.fontSize = Maths.Clamp(self.fontSize, UserConfig.MinFontSize, UserConfig.MaxFontSize)
            reaper.ImGui_TreePop(self.ctx)
        end
    end

    if reaper.ImGui_Button(self.ctx, "Apply") then
        self.config:Write(self.configKeyFontSize, self.fontSize);
    end
end

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = UserConfig(file)

reaper.defer(function() gui:Loop() end)
