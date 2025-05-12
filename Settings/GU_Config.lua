-- @description GUtilities scripts config
-- @author guonaudio
-- @version 1.4
-- @changelog
--   Remove os, and deb libs (refactored into global)
-- @about
--   Provides global settings for GUtilities Scripts
--   This script must be included by ReaPack to ensure all libraries are donwloaded

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_filesystem')
require('Lua.gutil_maths')
require('Reaper.gutil_config')
require('Reaper.gutil_gui')

---@class UserConfig : GuiBase
UserConfig = GuiBase:extend()

UserConfig.MinFontSize = 10
UserConfig.MaxFontSize = 36

function UserConfig:new(name)
    UserConfig.super.new(self, name, "NA")

    self.configKeyFontSize = "fontSize"
    self.config = Config("UserConfig")

    self.fontSize = self.config:ReadNumber(self.configKeyFontSize) or 14
end

function UserConfig:Frame()
    if ImGui.CollapsingHeader(self.ctx, "General", true) then
        if ImGui.TreeNode(self.ctx, "Font") then
            _, self.fontSize = ImGui.InputInt(self.ctx, "Font Size", toint(self.fontSize))

            if ImGui.IsItemHovered(self.ctx) then
                ImGui.SetTooltip(self.ctx, "Open & close running windows to refresh font size")
            end

            self.fontSize = Maths.Clamp(self.fontSize, UserConfig.MinFontSize, UserConfig.MaxFontSize)
            ImGui.TreePop(self.ctx)
        end
    end

    if ImGui.Button(self.ctx, "Apply") then
        self.config:Write(self.configKeyFontSize, self.fontSize);
    end
end

local scriptPath <const> = debug.getinfo(1).source

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = UserConfig(file)

reaper.defer(function () gui:Loop() end)
