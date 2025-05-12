-- @description Batch import
-- @author guonaudio
-- @version 1.3
-- @changelog
--   Remove os, debug and dialog libs (refactored into global)
-- @about
--   Batch imports media files recursively from a given source directory

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_classic')
require('Lua.gutil_filesystem')
require('Lua.gutil_maths')
require('Reaper.gutil_action')
require('Reaper.gutil_config')
require('Reaper.gutil_item')
require('Reaper.gutil_progressbar')
require('Reaper.gutil_project')
require('Reaper.gutil_take')
require('Reaper.gutil_track')

---@class BatchImporter : Object, Action
---@operator call: BatchImporter
---@field prog ProgressBarManager
BatchImporter = Object:extend()
BatchImporter:implement(Action)

BatchImporter.MaxFileSizeWarning = 1000 -- in MegaBytes
BatchImporter.MaxItemCountWarning = 100
BatchImporter.JobSize = 20 -- How many to do per frame

---@param file string
---@param undoText string
function BatchImporter:new(file, undoText)
    self.undoText = undoText
    self.shouldRun = false

    self.config = Config(FileSys.GetRawName(file))
    self.pathKey = "rootPath"

    self.path = FileSys.FolderDialog(self.config:ReadString(self.pathKey), "Browse for folder")
    if self.path == nil then return end

    self.currentDirectoryTokens = FileSys.Path.Split(self.path)
    self.project = Project(THIS_PROJECT)
    self.tracks = self.project:GetAllTracks()

    self.itemPosition = 0
    self.previousTrackDepth = -1

    local fileCount <const>, fileSize <const> = reaper.GU_Filesystem_CountMediaFiles(self.path, 0)
    Debug.Log("Counted: %d media items, totalling: %fMb\n", fileCount, fileSize)

    if fileCount < 0 then
        return
    end

    if fileSize > BatchImporter.MaxFileSizeWarning then
        if Dialog.MB("Total file size is greater than 1GB, continue?", "Warning", 1) == 2 then return end
    end

    if fileCount > BatchImporter.MaxItemCountWarning then
        if Dialog.MB("More than 100 files counted, continue?", "Warning", 1) == 2 then return end
    end

    self:Init(fileCount)
    self.shouldRun = true

    self.config:Write(self.pathKey, self.path)
end

function BatchImporter:PromptForSplay()
    self.shouldSplay = (Dialog.MB("Do you want to splay items?", "Import media", 4) == 6)
end

function BatchImporter:CreateFirstFolder()
    local dir <const> = FileSys.Path.Split(self.path)
    local trackName <const> = dir[#dir]
    local track <const> = self.project:CreateNewTrack(#self.tracks, trackName)
    track:SetValue("I_FOLDERDEPTH", 1) -- set as parent
    table.insert(self.tracks, track)
end

---@param folder string
---@param depth integer
function BatchImporter:ImportFolder(folder, depth)
    local track <const> = self.project:CreateNewTrack(#self.tracks, folder)
    track:SetValue("I_FOLDERDEPTH", 1) -- set as parent
    table.insert(self.tracks, track)

    if not self.shouldSplay then self.itemPosition = 0 end

    local currentTrack <const> = self.tracks[#self.tracks]
    local previousTrack <const> = self.tracks[#self.tracks - 1]

    if depth > self.previousTrackDepth then
        previousTrack:SetValue("I_FOLDERDEPTH", 1)
    elseif depth < self.previousTrackDepth then
        local depthDifference = depth - self.previousTrackDepth
        currentTrack:SetValue("I_FOLDERDEPTH", 1)
        previousTrack:SetValue("I_FOLDERDEPTH", depthDifference)
    else
        previousTrack:SetValue("I_FOLDERDEPTH", 0)
    end

    self.previousTrackDepth = depth
end

function BatchImporter:ImportFile(mediaItem)
    local track <const> = self.tracks[#self.tracks]
    local item <const> = track:CreateNewItem(mediaItem, self.itemPosition)
    self.itemPosition = self.itemPosition + item:GetValue("D_LENGTH")
    item:SetSelected(true)
end

function BatchImporter:BookendFinalTrack()
    if #self.tracks <= 0 then return end
    local finalTrack <const> = self.tracks[#self.tracks] ---@type Track
    finalTrack:SetValue("I_FOLDERDEPTH", Maths.Int32Min) -- arbitrarily small, ensure that it is bookended no matter what
end

function BatchImporter:ProgressBarInit(count)
    self.prog = {
        num = 0,
        denom = count,
        gui = ProgressBar("Importing media, please wait...")
    }
    reaper.defer(function () self.prog.gui:Loop() end)
end

function BatchImporter:ProgressBarUpdate()
    self.prog.num = self.prog.num + 1
    assert(self.prog.denom ~= nil and self.prog.denom > 0)
    self.prog.gui.fraction = self.prog.num / self.prog.denom
end

function BatchImporter:RecursivelyImportMediaFiles()
    if not self.shouldRun then return end

    local shouldDefer = true
    for _ = 0, BatchImporter.JobSize do
        local mediaPath <const> = reaper.GU_Filesystem_EnumerateMediaFiles(self.path, 0)

        if Str.IsNilOrEmpty(mediaPath) then
            self:Complete()
            shouldDefer = false
            break
        else
            self:ProgressBarUpdate()

            local directoryTokens <const> = FileSys.Path.Split(mediaPath)
            local tokens <const> = FileSys.Path.Difference(self.currentDirectoryTokens, directoryTokens)

            if next(tokens) then
                for depth, folder in pairs(tokens) do
                    self:ImportFolder(folder, depth)
                end
                self.currentDirectoryTokens = directoryTokens
            else
                self:ImportFile(mediaPath)
            end

            if self.prog.gui.shouldTerminate then
                self:Cancel()
                shouldDefer = false
                break
            end
        end
    end

    if shouldDefer then
        reaper.defer(function () self:RecursivelyImportMediaFiles() end)
    end
end

function BatchImporter:Init(fileCount)
    self:Begin()

    self:BookendFinalTrack()
    self:CreateFirstFolder()
    self:PromptForSplay()

    self:ProgressBarInit(fileCount)
end

local scriptPath <const> = debug.getinfo(1).source

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

BatchImporter(file, "Batch import"):RecursivelyImportMediaFiles()