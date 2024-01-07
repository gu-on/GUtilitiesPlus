-- @description Batch replace source
-- @author guonaudio
-- @version 1.0b
-- @changelog
--   Pre-release
-- @about
--   Batch replaces the source for the selected item's active take
--   Search and replace is run recursively for a given path

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/gui_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")

local BatchReplacer <const> = GuiBase:extend();

function BatchReplacer:new(name, undoText)
    BatchReplacer.super.new(self, name, undoText)

    self.config = Config(FileSys.GetRawName(name))
    self.pathKey = "rootPath"
    self.searchKey = "search"
    self.replaceKey = "replace"
    self.shouldReplaceInNameKey = "shouldReplaceInName"

    self.pathColor = Col.White

    local rv
    rv = self.config:Read(self.pathKey)
    self.path = rv or ""

    rv = self.config:Read(self.searchKey)
    self.search = rv or ""

    rv = self.config:Read(self.replaceKey)
    self.replace = rv or ""

    rv = self.config:Read(self.shouldReplaceInNameKey)
    self.shouldReplaceInName = rv or true

    self.windowWidth = 400
    self.windowHeight = 298
end

function BatchReplacer:GetFirstSelectedItemActiveTakeName()
    if reaper.CountSelectedMediaItems(THIS_PROJECT) < 1 then return "" end
    local itemPtr <const> = reaper.GetSelectedMediaItem(THIS_PROJECT, 0)
    if itemPtr == nil then return "" end
    local takePtr <const> = Item(itemPtr):GetActiveTakePtr()
    if takePtr == nil then return "" end
    return tostring(Take(takePtr))
end

function BatchReplacer:ReplaceItemSource()
    local items <const> = Items(FillType.Selected)
    for _, item in pairs(items.array) do
        local takePtr <const> = item:GetActiveTakePtr()

        if takePtr == nil then goto continue end -- skip blank item

        local rv <const>, _, start <const>, length <const>, fade <const>, reverse <const> =
            reaper.BR_GetMediaSourceProperties(takePtr)

        if rv then
            -- if "section" is enabled, it causes source get name to fail
            reaper.BR_SetMediaSourceProperties(takePtr, false, start, length, fade, reverse)
        else
            Debug:Log("Failed to GetMediaSourceProperties for %s", item:GetGuid())
            goto continue
        end

        local take <const> = Take(takePtr)
        local sourcePtr <const> = take:GetSourcePtr()

        if sourcePtr == nil then goto continue end -- skip invalid source
        local source <const> = Source(sourcePtr)

        local sourceName <const> = source:GetFileName()
        if GUtil.IsNilOrEmpty(sourceName) then -- strange bug where source is returning nil
            Debug:Log("Cannot get active take source name for %s", item)
            goto continue
        end

        local replaceString <const> = string.gsub(sourceName, self.search, self.replace)

        local newPath <const> = reaper.GU_Filesystem_FindFileInPath(self.path, replaceString)

        if GUtil.IsNilOrEmpty(newPath) then goto continue end -- not found

        take:SetAudioSource(newPath)
        if self.shouldReplaceInName then
            take:SetName(replaceString)
        end

        reaper.UpdateItemInProject(item.ptr)

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
    local vp <const> = reaper.ImGui_GetWindowViewport(self.ctx)
    local windowWidth <const>, _ = reaper.ImGui_Viewport_GetSize(vp)
    local scaledWindowWidth <const> = windowWidth * 0.65

    local rv
    rv, self.path = reaper.ImGui_InputText(self.ctx, "Path", self.path, reaper.ImGui_InputTextFlags_None())
    if rv then
        self.pathColor = FileSys.Path.Exists(self.path) and Col.White or Col.Red
    end
    if reaper.ImGui_Button(self.ctx, "GetPath", scaledWindowWidth) then
        self:GetPath()
    end
    _, self.search = reaper.ImGui_InputText(self.ctx, "Search", self.search, reaper.ImGui_InputTextFlags_None())
    _, self.replace = reaper.ImGui_InputText(self.ctx, "Replace", self.replace, reaper.ImGui_InputTextFlags_None())

    if reaper.ImGui_Button(self.ctx, "Swap", scaledWindowWidth) then
        local temp <const> = self.search
        self.search = self.replace
        self.replace = temp
    end

    _, self.shouldReplaceInName = reaper.ImGui_Checkbox(self.ctx, "Should Replace In Name", self.shouldReplaceInName)

    reaper.ImGui_Separator(self.ctx)

    reaper.ImGui_Text(self.ctx, "Path To Search:")
    reaper.ImGui_PushStyleColor(self.ctx, 0, self.pathColor)
    reaper.ImGui_Indent(self.ctx)
    reaper.ImGui_TextWrapped(self.ctx, self.path)
    reaper.ImGui_Unindent(self.ctx)
    reaper.ImGui_PopStyleColor(self.ctx, 1)

    local takeName <const> = self:GetFirstSelectedItemActiveTakeName()
    local replacementName <const> = takeName:gsub(self.search, self.replace)
    reaper.ImGui_Text(self.ctx, "First selected item:")
    reaper.ImGui_Indent(self.ctx)
    reaper.ImGui_Text(self.ctx, takeName)
    reaper.ImGui_Unindent(self.ctx)

    reaper.ImGui_Text(self.ctx, "Should be replaced by:")
    reaper.ImGui_Indent(self.ctx)
    reaper.ImGui_Text(self.ctx, replacementName)
    reaper.ImGui_Unindent(self.ctx)

    if reaper.ImGui_Button(self.ctx, "Activate", scaledWindowWidth) or reaper.ImGui_IsEnterKeyPressed(self.ctx) then
        if FileSys.Path.Exists(self.path) then
            self:Begin()
            self:ReplaceItemSource()
            self:SaveConfigFile()
            self:Complete(reaper.UndoState.Items)
        else
            reaper.MB("Path is invalid. Please provide a valid path before proceeding", "Warning",
                MessageBoxType.OK)
        end
    end
end

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

local gui <const> = BatchReplacer(file, "Replace selected items' active take's source")

reaper.defer(function () gui:Loop() end)
