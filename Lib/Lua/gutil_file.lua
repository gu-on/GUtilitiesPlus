-- @noindex

---@class File : Object
File = Object:extend()

File.Mode = { Read = "r", Write = "w" }

---@alias FileMode
---| "r" # Read mode.
---| "w" # Write mode.
---| "a" # Append mode.
---| "r+" # Update mode, all previous data is preserved.
---| "w+" # Update mode, all previous data is erased.
---| "a+" # Append update mode, previous data is preserved, writing is only allowed at the end of file.
---| "rb" # Read mode. (in binary mode.)
---| "wb" # Write mode. (in binary mode.)
---| "ab" # Append mode. (in binary mode.)
---| "r+b" # Update mode, all previous data is preserved. (in binary mode.)
---| "w+b" # Update mode, all previous data is erased. (in binary mode.)
---| "a+b" # Append update mode, previous data is preserved, writing is only allowed at the end of file. (in binary mode.)

---@param path string
---@param mode FileMode
function File:new(path, mode)
    path = path or FileSys.Path.Default()
    mode = mode or File.Mode.Read
    self.isOpen = false
    local file <const>, err <const> = io.open(path, mode)
    if file == nil then
        error("file creation failed\nerr: " .. err)
    end
    self.file = file
    self.isOpen = true
end

function File:__close() if self.isOpen then return self.file:close() end end

function File:Write(s) self.file:write(s) end

return File