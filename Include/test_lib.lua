-- @version 1.0
-- @noindex

_INCLUDED = _INCLUDED or {}

dofile(debug.getinfo(1).source:match("@?(.*[\\|/])") .. "classic.lua")

Test = Object:extend()

function Test:new(name, func)
    self.name = name or ''
    self.func = func or nil
end

TestRunner = Object:extend()

function TestRunner:new(name, tests)
    self.name = name or ''
    self.tests = tests or {}
end

function TestRunner:Run()
    reaper.ShowConsoleMsg("RUNNING TESTS FOR " .. self.name .. "\n\n")
    local passedCount = 0

    for _, test in ipairs(self.tests) do
        local hasPassed <const>, errorMessage <const> = pcall(test.func)
        if hasPassed then
            passedCount = passedCount + 1
            reaper.ShowConsoleMsg("PASS: " .. test.name .. "\n")
        else
            reaper.ShowConsoleMsg("FAIL: " .. test.name .. errorMessage .. "\n")
        end
    end

    reaper.ShowConsoleMsg("\n")
    reaper.ShowConsoleMsg(passedCount .. "/" .. #self.tests .. " tests passed\n")
    reaper.ShowConsoleMsg("================\n\n")

    return passedCount >= #self.tests
end
