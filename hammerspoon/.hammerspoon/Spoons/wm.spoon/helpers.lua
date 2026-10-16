-- LaWM Helpers
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
    local layout = self.spoon.layouts and self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
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

    -- Check keywords and mark as floating if found
    local function checkKeywords(keywords)
        for _, keyword in ipairs(keywords) do
            if string.find(lowerTitle, string.lower(keyword)) then
                self.spoon.state.floatingWindows[win:id()] = true
                return true
            end
        end
        return false
    end

    -- Check status and settings keywords
    if checkKeywords(self.spoon.config.statusKeywords) or
        checkKeywords(self.spoon.config.settingsKeywords) then
        return false
    end

    -- Advanced settings detection
    if self:isSettingsWindow(win, appName, title) then
        self.spoon.state.floatingWindows[win:id()] = true
        return false
    end

    -- Check small window threshold
    local frame = win:frame()
    local threshold = self.spoon.config.smallWindowThreshold
    if frame.w < threshold.width and frame.h < threshold.height then
        self.spoon.state.floatingWindows[win:id()] = true
        return false
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
    local frame = win:frame()
    if frame.w < 800 and frame.h < 600 then
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
    local layout = self.spoon.layouts and self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
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
