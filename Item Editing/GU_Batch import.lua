-- @description Batch import
-- @author guonaudio
-- @version 1.0
-- @changelog
--   Initial release
-- @about
--   Batch imports media files recursively from a given source directory

local scriptPath <const> = debug.getinfo(1).source
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/reaper_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/gui_lib.lua")
dofile(scriptPath:match("@?(.*[\\|/])") .. "../Include/utils_lib.lua")

local BatchImporter <const> = Action:extend();

BatchImporter.MaxFileSizeWarning = 1000 -- in MegaBytes
BatchImporter.MaxItemCountWarning = 100
BatchImporter.JobSize = 20              -- How many to do per frame

function BatchImporter:new(file, undoText)
    self.undoText = undoText

    self.config = Config(FileSys.GetRawName(file))
    self.pathKey = "rootPath"

    self.path = FileSys.FolderDialog(self.config:Read(self.pathKey), "Browse for folder")
    if self.path == nil then return end

    self.currentDirectoryTokens = FileSys.Path.Split(self.path)
    self.tracks = Tracks(FillType.All)

    self.itemPosition = 0
    self.previousTrackDepth = -1
    self.shouldRun = true

    local fileCount <const>, fileSize <const> = reaper.GU_Filesystem_CountMediaFiles(self.path, 0)
    Debug:Log("Counted: %d media items, totalling: %fMb\n", fileCount, fileSize)

    if fileCount < 0 then
        self.shouldRun = false
        return
    end

    if fileSize > BatchImporter.MaxFileSizeWarning then
        if reaper.MB("Total file size is greater than 1GB, continue?", "Warning", MessageBoxType.OKCANCEL) == MessageBoxReturn.CANCEL then
            self.shouldRun = false
            return
        end
    end

    if fileCount > BatchImporter.MaxItemCountWarning then
        if reaper.MB("More than 100 files counted, continue?", "Warning", MessageBoxType.OKCANCEL) == MessageBoxReturn.CANCEL then
            self.shouldRun = false
            return
        end
    end

    self:Init(fileCount)

    self.config:Write(self.pathKey, self.path)
end

function BatchImporter:PromptForSplay()
    local input <const> = reaper.MB("Do you want to splay items?", "Import media", MessageBoxType.YESNO)
    self.shouldSplay = input == MessageBoxReturn.YES
end

function BatchImporter:CreateFirstFolder()
    local dir <const> = FileSys.Path.Split(self.path)
    local trackName <const> = dir[#dir]
    self.tracks:CreateNew(trackName)
    self.tracks:End():SetFolderDepth(1) -- set as parent
end

function BatchImporter:ImportFolder(folder, depth)
    self.tracks:CreateNew(folder)

    if not self.shouldSplay then self.itemPosition = 0 end

    local currentTrack <const> = self.tracks:At(self.tracks:Size())
    local previousTrack <const> = self.tracks:At(self.tracks:Size() - 1)

    if depth > self.previousTrackDepth then
        previousTrack:SetFolderDepth(1)
    elseif depth < self.previousTrackDepth then
        local depthDifference = depth - self.previousTrackDepth
        currentTrack:SetFolderDepth(1)
        previousTrack:SetFolderDepth(depthDifference)
    else
        previousTrack:SetFolderDepth(0)
    end

    self.previousTrackDepth = depth
end

function BatchImporter:ImportFile(mediaItem)
    local track <const> = self.tracks:End()
    local item <const> = track:CreateNewItem(mediaItem, self.itemPosition)
    self.itemPosition = self.itemPosition + item:GetLength()
    item:Select()
end

function BatchImporter:BookendFinalTrack()
    if #self.tracks.array <= 0 then return end
    self.tracks:End():SetFolderDepth(Int32.min)
end

function BatchImporter:ProgressBarInit(count)
    self.prog = {}
    self.prog.num = 0
    self.prog.denom = count
    self.prog.gui = ProgressBar("Importing media, please wait...")
    reaper.defer(function () self.prog.gui:Loop() end)
end

function BatchImporter:ProgressBarUpdate()
    self.prog.num = self.prog.num + 1
    self.prog.gui.fraction = self.prog.num / self.prog.denom
end

function BatchImporter:RecursivelyImportMediaFiles()
    if not self.shouldRun then return end

    local shouldDefer = true
    for _ = 0, BatchImporter.JobSize do
        local mediaItem = reaper.GU_Filesystem_EnumerateMediaFiles(self.path, 0)

        if GUtil.IsNilOrEmpty(mediaItem) then
            self:Complete()
            shouldDefer = false
            break
        else
            self:ProgressBarUpdate()

            local directoryTokens <const> = FileSys.Path.Split(mediaItem)
            local tokens <const> = FileSys.Path.Difference(self.currentDirectoryTokens, directoryTokens)

            if next(tokens) then
                for depth, folder in pairs(tokens) do
                    self:ImportFolder(folder, depth)
                end
                self.currentDirectoryTokens = directoryTokens
            else
                self:ImportFile(mediaItem)
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

local _, file <const>, _ = FileSys.Path.Parse(scriptPath)

BatchImporter(file, "Batch import"):RecursivelyImportMediaFiles()
