-- WM Helpers
local Helpers = {}
Helpers.__index = Helpers

function Helpers:new(spoon)
    return setmetatable({ spoon = spoon }, self)
end

function Helpers:isRelevantWindow(win)
    if not win then return false end

    -- Use pcall for window operations that might fail
    local ok, isStandard = pcall(function() return win:isStandard() end)
    if not ok or not isStandard then return false end

    -- For stack layout: windows are intentionally hidden off-screen, so check if tracked
    local layout = self.spoon.layouts and self.spoon:getCurrentLayoutName()
    if layout == "stack" then
        local winId = win:id()
        -- If window is in our tracked windows list, it's relevant even if "not visible"
        if winId and self.spoon.state and self.spoon.state.windows then
            for _, w in ipairs(self.spoon.state.windows) do
                local ok, id = pcall(function() return w:id() end)
                if ok and id == winId then
                    return true -- Already tracked, keep it
                end
            end
        end
    end

    local ok2, isVisible = pcall(function() return win:isVisible() end)
    if not ok2 or not isVisible then return false end

    local app = win:application()
    if not app then return false end

    local appName = app:name()
    if not appName then return false end

    -- Check excluded apps
    local excluded = self.spoon.config.excludedApps
    if excluded[appName] or excluded[string.lower(appName)] then return false end

    local title = win:title() or ""
    local lowerTitle = string.lower(title)
    local winId = win:id()
    local frame = win:frame()
    local config = self.spoon.config

    local function markFloating()
        if winId then self.spoon.state.floatingWindows[winId] = true end
        return false
    end

    -- Title keywords only count for small windows: "Network - Wikipedia" is a normal browser tab,
    -- while a small "Network Settings" panel should float.
    local maxSize = config.keywordWindowMaxSize or { width = 1000, height = 700 }
    if frame.w < maxSize.width and frame.h < maxSize.height then
        for _, keywords in ipairs({ config.statusKeywords, config.settingsKeywords }) do
            for _, keyword in ipairs(keywords) do
                if string.find(lowerTitle, string.lower(keyword), 1, true) then
                    return markFloating()
                end
            end
        end
    end

    -- Advanced settings detection
    if self:isSettingsWindow(win, appName, title) then
        return markFloating()
    end

    -- Check small window threshold
    local threshold = config.smallWindowThreshold
    if frame.w < threshold.width and frame.h < threshold.height then
        return markFloating()
    end

    return true
end

function Helpers:isSettingsWindow(win, appName, title)
    -- Check window subrole
    local subrole = win:subrole()
    if subrole then
        local lowerSubrole = string.lower(subrole)
        if subrole == "AXSystemDialog" or subrole == "AXDialog" or
            string.find(lowerSubrole, "pref") or string.find(lowerSubrole, "setting") then
            return true
        end
    end

    -- Title patterns below are only trusted for small windows (see isRelevantWindow)
    local maxSize = self.spoon.config.keywordWindowMaxSize or { width = 1000, height = 700 }
    local size = win:frame()
    if size.w >= maxSize.width or size.h >= maxSize.height then return false end

    -- App-specific patterns - consolidated into table
    local appPatterns = {
        [appName .. " Preferences"] = true,
        [appName .. " Settings"] = true,
        [appName .. " Options"] = true,
        ["System Preferences"] = (appName == "System Preferences"),
        ["System Settings"] = (appName == "System Settings"),
        ["Preferences"] = true,
        ["Settings"] = true,
    }

    if appPatterns[title] then return true end

    -- Pattern matching - consolidated arrays
    local settingsPatterns = {
        "^preferences$", "^settings$", "^options$", "^configuration$",
        "preferences$", "settings$", "options$", " settings$", " preferences$",
        "^about ", "^inspector ", "^properties ", "account settings",
        "privacy settings", "security settings", "network settings",
        "display settings", "audio settings", "keyboard settings"
    }

    local lowerTitle = string.lower(title)
    for _, pattern in ipairs(settingsPatterns) do
        if string.match(lowerTitle, pattern) then return true end
    end

    -- Size-based detection with keywords
    if size.w < 800 and size.h < 600 then
        local settingsWords = { "setting", "preference", "config", "option" }
        for _, word in ipairs(settingsWords) do
            if string.find(lowerTitle, word) then return true end
        end
    end

    return false
end

function Helpers:getRelevantWindows()
    local windows = {}
    local addedIds = {} -- Track which windows we've already added

    for _, win in ipairs(hs.window.allWindows()) do
        local winId = win:id()
        if winId and not addedIds[winId] then
            if self:isRelevantWindow(win) and not self.spoon.state.floatingWindows[winId] then
                table.insert(windows, win)
                addedIds[winId] = true
            end
        end
    end

    -- For stack layout: ensure all tracked windows are included even if hidden off-screen
    local layout = self.spoon.layouts and self.spoon:getCurrentLayoutName()
    if layout == "stack" and self.spoon.state and self.spoon.state.windows then
        for _, win in ipairs(self.spoon.state.windows) do
            local ok, winId = pcall(function() return win:id() end)
            if ok and winId and not addedIds[winId] then
                -- Verify window still exists and is standard
                local ok2, isStandard = pcall(function() return win:isStandard() end)
                if ok2 and isStandard and not self.spoon.state.floatingWindows[winId] then
                    table.insert(windows, win)
                    addedIds[winId] = true
                end
            end
        end
    end

    return windows
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

-- Helper function to safely get window ID
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
