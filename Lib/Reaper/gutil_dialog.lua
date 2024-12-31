-- @noindex

---@alias MessageBoxType
---| 0 # OK
---| 1 # OKCANCEL
---| 2 # ABORTRETRYIGNORE
---| 3 # YESNOCANCEL
---| 4 # YESNO
---| 5 # RETRYCANCEL

---@alias MessageBoxReturn
---| 1 # OK
---| 2 # CANCEL
---| 3 # ABORT
---| 4 # RETRY
---| 5 # IGNORE
---| 6 # YES
---| 7 # NO

---@class Dialog : Object
Dialog = Object:extend()

---comment
---@param msg string
---@param title string
---@param mbtype MessageBoxType
---@return MessageBoxReturn
function Dialog.MB(msg, title, mbtype)
    return reaper.MB(msg, title, mbtype)
end

return Dialog