-- @description Batch replace source
-- @author guonaudio
-- @version 1.1b
-- @changelog
--   Refactor to make better use of Lua Language Server
-- @about
--   Batch replaces the source for the selected item's active take
--   Search and replace is run recursively for a given path

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('lua.gutil_classic')
require('lua.gutil_color')
require('lua.gutil_filesystem')
require('reaper.gutil_config')
require('reaper.gutil_debug')
require('reaper.gutil_gui')
require('reaper.gutil_item')
require('reaper.gutil_os')
require('reaper.gutil_project')
require('reaper.gutil_source')
require('reaper.gutil_take')

---@class BatchReplacer : GuiBase
---@operator call: BatchReplacer
BatchReplacer = GuiBase:extend()

function BatchReplacer:new(name, undoText)
    BatchReplacer.super:new(name, undoText)

    self.config = Config(FileSys.GetRawName(name))
    self.pathKey = "rootPath"
    self.searchKey = "search"
    self.replaceKey = "replace"
    self.shouldReplaceInNameKey = "shouldReplaceInName"

    self.pathColor = Color.White

    self.path = self.config:ReadString(self.pathKey) or ""
    self.search = self.config:ReadString(self.searchKey) or ""
    self.replace = self.config:ReadString(self.replaceKey) or ""
    self.shouldReplaceInName = self.config:ReadBool(self.shouldReplaceInNameKey) or true

    self.windowWidth = 400
    self.windowHeight = 298
end

function BatchReplacer:GetFirstSelectedItemActiveTakeName()
    local items <const> = Project(THIS_PROJECT):GetSelectedItems()
    if #items == 0 then return "" end

    local take <const> = items[1]:GetActiveTake()
    if not take:IsValid() then return "" end

    local source <const> = take:GetSource()
    if not source:IsValid() then return "" end

    return source:GetFileName()
end

function BatchReplacer:ReplaceItemSource()
    local items <const> = Project(THIS_PROJECT):GetSelectedItems()
    for _, item in ipairs(items) do
        local take <const> = item:GetActiveTake()
        if not take:IsValid() then goto continue end -- skip blank item

        local rv <const>, _, start <const>, length <const>, fade <const>, reverse <const> =
            reaper.BR_GetMediaSourceProperties(take.id)

        if rv then
            -- if "section" is enabled, it causes source get name to fail
            reaper.BR_SetMediaSourceProperties(take.id, false, start, length, fade, reverse)
        else
            Debug.Log("Failed to GetMediaSourceProperties for %s", item.id)
            goto continue
        end

        local source <const> = take:GetSource()
        if not source:IsValid() then goto continue end -- skip invalid source

        local sourceName <const> = source:GetFileName()
        if Str.IsNilOrEmpty(sourceName) then -- strange bug where source is returning nil
            Debug.Log("Cannot get active take source name for %s", item)
            goto continue
        end

        local replaceString <const> = sourceName:gsub(self.search, self.replace)

        local newPath <const> = FileSys.Path.Find(self.path, replaceString)

        if Str.IsNilOrEmpty(newPath) then goto continue end -- not found

        take:SetAudioSource(newPath)
        if self.shouldReplaceInName then
            take:SetString("P_NAME", replaceString)
        end

        item:UpdateInProject()

        ::continue::
    end
    reaper.Main_OnCommandEx(40047, 0, THIS_PROJECT)
end

function BatchReplacer:SaveConfigFile()
    self.config:Write(self.pathKey, self.path)
    self.config:Write(self.searchKey, self.search)
    self.config:Write(self.replaceKey, self.replace)
    self.config:Write(self.shouldReplaceInNameKey, self.shouldReplaceInName)
end

function BatchReplacer:GetPath()
    local path <const> = FileSys.FolderDialog(self.path, "Get Path")

    if path ~= nil then self.path = path end
end

function BatchReplacer:Frame()
    local windowWidth <const>, _ = ImGui.Viewport_GetSize(ImGui.GetWindowViewport(self.ctx))
    local scaledWindowWidth <const> = windowWidth * 0.65

    local rv
    rv, self.path = ImGui.InputText(self.ctx, "Path", self.path, ImGui.InputTextFlags_None)
    if ImGui.Button(self.ctx, "GetPath", scaledWindowWidth) then
        self:GetPath()
    end
    rv, self.search = ImGui.InputText(self.ctx, "Search", self.search, ImGui.InputTextFlags_None)
    rv, self.replace = ImGui.InputText(self.ctx, "Replace", self.replace, ImGui.InputTextFlags_None)

    self.pathColor = FileSys.Path.Find(self.path, self.replace) ~= "" and Color.White or Color.Red

    if ImGui.Button(self.ctx, "Swap", scaledWindowWidth) then
        local temp <const> = self.search
        self.search = self.replace
        self.replace = temp
    end

    _, self.shouldReplaceInName = ImGui.Checkbox(self.ctx, "Should Replace In Name", self.shouldReplaceInName)

    ImGui.Separator(self.ctx)

    ImGui.Text(self.ctx, "Path To Search:")
    ImGui.PushStyleColor(self.ctx, 0, self.pathColor)
    ImGui.Indent(self.ctx)
    ImGui.TextWrapped(self.ctx, self.path .. "\\" .. self.replace)
    ImGui.Unindent(self.ctx)
    ImGui.PopStyleColor(self.ctx, 1)

    local takeName <const> = self:GetFirstSelectedItemActiveTakeName()
    local replacementName <const> = takeName:gsub(self.search, self.replace)
    ImGui.Text(self.ctx, "First selected item:")
    ImGui.Indent(self.ctx)
    ImGui.Text(self.ctx, takeName)
    ImGui.Unindent(self.ctx)

    ImGui.Text(self.ctx, "Should be replaced by:")
    ImGui.Indent(self.ctx)
    ImGui.Text(self.ctx, replacementName)
    ImGui.Unindent(self.ctx)

    if ImGui.Button(self.ctx, "Activate", scaledWindowWidth) or ImGuiExt.IsEnterKeyPressed(self.ctx) then
        if not FileSys.Path.Exists(self.path) then
            Dialog.MB("Path is invalid. Please provide a valid path before proceeding", "Warning", 0)
        else
            self:Begin()
            self:ReplaceItemSource()
            self:SaveConfigFile()
            self:Complete(4)
            self:Close()
        end
    end
end

local scriptPath <const> = debug.getinfo(1).source

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = BatchReplacer(file, "Replace selected items' active take's source")

reaper.defer(function () gui:Loop() end)
