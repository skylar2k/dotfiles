-- LaWM Helpers
local Helpers = {}
Helpers.__index = Helpers

function Helpers:new(spoon)
    return setmetatable({ spoon = spoon }, self)
end

function Helpers:getScreenFrame()
    local screen = hs.screen.mainScreen()
    if not screen then return nil end

    local frame = screen:frame()
    if not frame then return nil end

    local gap = self.spoon.config.gap or 8
    return {
        x = frame.x + gap,
        y = frame.y + gap,
        w = frame.w - (gap * 2),
        h = frame.h - (gap * 2)
    }
end

-- Safely get a window's id
function Helpers:getWindowId(win)
    local ok, id = pcall(function() return win and win:id() end)
    return ok and id or nil
end

-- Centralized logging
function Helpers:log(level, message)
    if level == "debug" and not self.spoon.config.debug then
        return -- Skip debug messages unless debug mode is enabled
    end
    print("[WM " .. level .. "] " .. message)
end

return Helpers
