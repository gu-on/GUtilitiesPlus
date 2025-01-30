-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Reaper.gutil_debug')

---@class Action : Object
---@operator call: Action
Action = Object:extend()

function Action:new()
    self.undoText = ""
end

function Action:Begin()
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    Debug.Log("Action Begin\n")
end

---@param undoState UndoState?
function Action:Complete(undoState)
    undoState = undoState or -1
    reaper.Undo_EndBlock(self.undoText, undoState)
    reaper.PreventUIRefresh(-1)
    local command <const> = 40245 ---@type CommandID
    reaper.Main_OnCommandEx(command, 0, THIS_PROJECT)
    Debug.Log("Action Complete: %s\n", self.undoText)
end

function Action:Cancel()
    reaper.Undo_DoUndo2(THIS_PROJECT)
    reaper.PreventUIRefresh(-1)
    Debug.Log("Action Cancel\n")
end

return Action