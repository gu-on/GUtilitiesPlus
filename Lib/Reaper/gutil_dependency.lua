-- @noindex

---@class Dependency
Dependency = {}

local dependencyInfo <const> = {
    { Name = "SWS",             Func = "CF_GetSWSVersion",        Web = "https://www.sws-extension.org" },
    { Name = "ReaImGui",        Func = "ImGui_GetVersion",        Web = "https://forum.cockos.com/showthread.php?t=250419" },
    { Name = "js_ReaScriptAPI", Func = "JS_ReaScriptAPI_Version", Web = "https://forum.cockos.com/showthread.php?t=212174" },
}

function Dependency.CheckGUtilitiesAPI()
    if not reaper.APIExists("GU_GUtilitiesAPI_GetVersion") then
        error(
            "GUtilitiesAPI is not installed. Please use ReaPack's Browse Packages feature and ensure that it is installed. " ..
            "If you have installed it during this session, you will need to restart Reaper before it can be loaded.")
    end
end

function Dependency.CheckAll()
    local mbMsg <const> = " is not installed.\n\nWould you like to be redirected now?"
    local errorMsg <const> = " is not installed.\n\nPlease ensure it is installed before using this script"

    Dependency.CheckGUtilitiesAPI()
    for _, info in pairs(dependencyInfo) do
        if not reaper.APIExists(info.Func) then
            local input <const> = Dialog.MB(info.Name .. mbMsg, "Error", 1)
            if input == 1 then
                Cmd.OpenURL(info.Web)
            end
            error(info.Name .. errorMsg)
        end
    end
end

return Dependency