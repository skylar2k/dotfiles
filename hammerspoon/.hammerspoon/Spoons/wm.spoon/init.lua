-- LaWM (Lattice Window Manager)
local obj = {}
obj.__index = obj

-- Configuration with consolidated structure
obj.config = {
    debug = false, -- Enable debug logging
    gap = 8,
    excludedApps = {},
    statusKeywords = { "status", "copy", "progress", "loading", "downloading" },
    settingsKeywords = {
        -- English
        "settings", "preferences", "prefs", "options", "configuration", "config",
        "setup", "properties", "about", "inspector", "info", "information",
        -- App-specific patterns
        "preference", "setting", "option", "configure", "account", "profile",
        "general", "advanced", "privacy", "security", "network", "display",
        -- Other languages
        "préférences", "einstellungen", "configuración", "impostazioni", "設定", "环境设置"
    },
    usePerSpaceLayouts = true,

    -- Consolidated sub-configs
    resizing = { step = 0.05, minRatio = 0.15, maxRatio = 0.85 },
    timing = { layoutUpdateDelay = 0.08, spaceChangeDelay = 0.12, initialSetupDelay = 0.15, windowLockDuration = 0.4 },
    smallWindowThreshold = { width = 450, height = 320 },
    focusedWindowIndicator = { width = 50, height = 4, opacity = 0.9, borderRadius = 2 },
    stackIndicators = { enabled = true, position = "bottomLeft", width = 40, height = 5, spacing = 5, maxIndicators = 10, borderRadius = 2.5 },
    alerts = {
        enabled = true,
        position = "bottom",
        duration = 0.8,
        fadeIn = 0.15,
        fadeOut = 0.25,
        strokeWidth = 0,
        fillColor = { white = 0.05, alpha = 0.85 },
        textColor = { white = 0.95, alpha = 1 },
        textSize = 15,
        radius = 8
    },

    -- Mode colors
    modeColors = {
        tile = { red = 0.286, green = 0.729, blue = 0.929, alpha = 1 },   -- Blue
        scroll = { red = 0.608, green = 0.349, blue = 0.714, alpha = 1 }, -- Purple
        stack = { red = 0.0, green = 0.475, blue = 0.549, alpha = 1 },    -- Teal
    },

    -- Menubar workspace indicator
    menubar = {
        enabled = true,
        showWindowCount = true,
        activeColor = { red = 0.4, green = 0.8, blue = 0.4 },
        inactiveColor = { red = 0.5, green = 0.5, blue = 0.5 },
        hasWindowsColor = { red = 0.8, green = 0.8, blue = 0.8 },
        -- Workspace names (defaults to numbers if not set)
        workspaceNames = {},
        -- Per-workspace colors (optional, uses layout color if not set)
        workspaceColors = {},
    }
}

-- Constants and initial state
obj.layouts = { "tile", "scroll", "stack" }
obj.settingsFile = hs.fs.pathToAbsolute("~/.hammerspoon/wm_settings.json")
obj.state = {
    currentLayout = 1,
    windows = {},
    floatingWindows = {},
    floatingSteps = {},
    splitRatios = {},
    tilingEnabled = true, -- Global tiling toggle
    splitDirections = {},
    windowTree = {},
    spaceLayouts = {},
    spaceWindowOrder = {},
    layoutChanged = false,
    ignoreNextUpdate = false,
    alertUUID = nil,
    fullscreenWindows = {}
}

-- Load modules
local Core = dofile(hs.spoons.resourcePath("core.lua"))
local UI = dofile(hs.spoons.resourcePath("ui.lua"))
local Helpers = dofile(hs.spoons.resourcePath("helpers.lua"))
local API = dofile(hs.spoons.resourcePath("api.lua"))
local WorkspaceManager = dofile(hs.spoons.resourcePath("workspace_manager.lua"))
local Layouts = dofile(hs.spoons.resourcePath("layouts.lua"))
local Menubar = dofile(hs.spoons.resourcePath("menubar.lua"))

-- Simplified color processing
function obj:hexToColor(hex, alpha)
    if type(hex) == "table" then return hex end

    hex = hex:gsub("#", "")
    return {
        red = tonumber(hex:sub(1, 2), 16) / 255,
        green = tonumber(hex:sub(3, 4), 16) / 255,
        blue = tonumber(hex:sub(5, 6), 16) / 255,
        alpha = alpha or 1.0
    }
end

function obj:processColors()
    -- Convert hex colors in modeColors
    for layout, color in pairs(self.config.modeColors) do
        if type(color) == "string" then
            self.config.modeColors[layout] = self:hexToColor(color)
        end
    end

    -- Convert alert colors
    local alerts = self.config.alerts
    if type(alerts.fillColor) == "string" then
        alerts.fillColor = self:hexToColor(alerts.fillColor, 0.85)
    end
    if type(alerts.textColor) == "string" then
        alerts.textColor = self:hexToColor(alerts.textColor, 1.0)
    end
end

function obj:init()
    self:processColors()

    -- Initialize modules
    self.helpers = Helpers:new(self)
    self.ui = UI:new(self)
    self.core = Core:new(self)
    self.api = API:new(self)
    self.workspaceManager = WorkspaceManager:new(self)
    self.layoutsModule = Layouts:new(self.config, self)
    self.menubar = Menubar:new(self)

    self:loadSettings()

    -- Apply saved workspace layouts
    if self.state.pendingWorkspaceLayouts then
        for i, layout in pairs(self.state.pendingWorkspaceLayouts) do
            local wsIndex = tonumber(i)
            if wsIndex and self.workspaceManager.workspaces[wsIndex] then
                self.workspaceManager.workspaces[wsIndex].layout = layout
            end
        end
        self.state.pendingWorkspaceLayouts = nil
    end

    return self
end

-- Space management functions
function obj:getCurrentSpaceID()
    local screen = hs.screen.mainScreen()
    return screen and tostring(hs.spaces.activeSpaceOnScreen(screen))
end

-- Get layout for current workspace (independent of macOS Spaces)
function obj:getLayoutForCurrentSpace()
    local wm = self.workspaceManager
    if wm then
        local ws = wm:getCurrentWorkspace()
        return ws.layout or 1
    end
    return self.state.currentLayout
end

-- Set layout for current workspace
function obj:setLayoutForCurrentSpace(layoutIndex)
    local wm = self.workspaceManager
    if wm then
        local ws = wm:getCurrentWorkspace()
        ws.layout = layoutIndex
    end
    self.state.currentLayout = layoutIndex
end

-- Window order management
function obj:saveWindowOrderForCurrentSpace()
    local spaceID = self:getCurrentSpaceID()
    if not spaceID or not self.state.windows then return end

    local windowOrder = {}
    for i, win in ipairs(self.state.windows) do
        if win then
            local ok, winId = pcall(function() return win:id() end)
            local isStandard = false
            pcall(function() isStandard = win:isStandard() end)

            if ok and winId and isStandard then
                local app = win:application()
                if app then
                    local appName = ""
                    local bundleID = ""
                    local title = ""
                    pcall(function() appName = app:name() or "" end)
                    pcall(function() bundleID = app:bundleID() or "" end)
                    pcall(function() title = win:title() or "" end)

                    table.insert(windowOrder, {
                        id = winId,
                        app = appName,
                        title = title,
                        bundleID = bundleID,
                        index = i
                    })
                end
            end
        end
    end

    self.state.spaceWindowOrder[spaceID] = windowOrder
end

function obj:restoreWindowOrderForCurrentSpace()
    local spaceID = self:getCurrentSpaceID()
    if not spaceID or not self.state.spaceWindowOrder[spaceID] then return false end

    local savedOrder = self.state.spaceWindowOrder[spaceID]

    -- Get windows from workspace manager if available, otherwise fallback
    local currentWindows
    local wm = self.workspaceManager
    if wm then
        currentWindows = wm:getWindowsForLayout()
    else
        currentWindows = self.helpers:getRelevantWindows()
    end

    if #currentWindows == 0 then return false end

    -- Create window map for quick lookup
    local windowMap = {}
    for _, win in ipairs(currentWindows) do
        local ok, winId = pcall(function() return win:id() end)
        if ok and winId then
            windowMap[winId] = win
        end
    end

    local orderedWindows, usedIds = {}, {}

    -- First pass: restore existing windows in saved order
    for _, saved in ipairs(savedOrder) do
        if saved.id and windowMap[saved.id] and not usedIds[saved.id] then
            table.insert(orderedWindows, windowMap[saved.id])
            usedIds[saved.id] = true
        end
    end

    -- Second pass: add remaining windows (new windows not in saved order)
    for _, win in ipairs(currentWindows) do
        local ok, winId = pcall(function() return win:id() end)
        if ok and winId and not usedIds[winId] then
            table.insert(orderedWindows, win)
            usedIds[winId] = true
        end
    end

    if #orderedWindows > 0 then
        self.state.windows = orderedWindows
        return true
    end

    return false
end

function obj:updateLayout(preserveOrder)
    -- Sync currentLayout from workspace manager
    local wm = self.workspaceManager
    if wm then
        local ws = wm:getCurrentWorkspace()
        self.state.currentLayout = ws.layout or 1
    end

    if not preserveOrder then
        preserveOrder = self:restoreWindowOrderForCurrentSpace()
    end

    self.core:updateLayout(preserveOrder)
    self:saveSettings()
end

-- Settings management with streamlined logic
function obj:loadSettings()
    local file = io.open(self.settingsFile, "r")
    if not file then return end

    local content = file:read("*all")
    file:close()

    local success, settings = pcall(hs.json.decode, content)
    if not success or not settings then return end

    -- Load state (excluding runtime-only fields)
    local excludedStateKeys = { alertUUID = true, floatingWindows = true, floatingSteps = true }
    for k, v in pairs(settings) do
        if self.state[k] ~= nil and not excludedStateKeys[k] then
            self.state[k] = v
        end
    end

    -- Convert floating window/step IDs from strings to numbers
    local function convertIds(source, target)
        if source then
            for k, v in pairs(source) do
                target[tonumber(k)] = v
            end
        end
    end

    convertIds(settings.floatingWindows, self.state.floatingWindows)
    convertIds(settings.floatingSteps, self.state.floatingSteps)

    -- Store workspace layouts to apply after workspaceManager is initialized
    if settings.workspaceLayouts then
        self.state.pendingWorkspaceLayouts = settings.workspaceLayouts
    end

    -- Load config with deep merge
    if settings.config then
        for k, v in pairs(settings.config) do
            if type(v) == "table" and type(self.config[k]) == "table" then
                for nested_k, nested_v in pairs(v) do
                    self.config[k][nested_k] = nested_v
                end
            else
                self.config[k] = v
            end
        end
    end
end

function obj:saveSettings()
    -- Convert floating IDs to strings for JSON serialization
    local function convertIdsToStrings(source)
        local result = {}
        for id, v in pairs(source) do
            result[tostring(id)] = v
        end
        return result
    end

    -- Save workspace layouts
    local workspaceLayouts = {}
    if self.workspaceManager then
        for i = 1, 9 do
            workspaceLayouts[i] = self.workspaceManager.workspaces[i].layout
        end
    end

    local settings = {
        -- State
        currentLayout = self.state.currentLayout,
        splitRatios = self.state.splitRatios,
        splitDirections = self.state.splitDirections,
        floatingWindows = convertIdsToStrings(self.state.floatingWindows),
        floatingSteps = convertIdsToStrings(self.state.floatingSteps),
        spaceLayouts = self.state.spaceLayouts,
        spaceWindowOrder = self.state.spaceWindowOrder,
        workspaceLayouts = workspaceLayouts,

        -- Config (only user-modifiable parts)
        config = {
            usePerSpaceLayouts = self.config.usePerSpaceLayouts,
            settingsKeywords = self.config.settingsKeywords,
            resizing = self.config.resizing,
            timing = self.config.timing,
            smallWindowThreshold = self.config.smallWindowThreshold,
            focusedWindowIndicator = self.config.focusedWindowIndicator,
            alerts = self.config.alerts,
            stackIndicators = self.config.stackIndicators
        }
    }

    local success, json = pcall(hs.json.encode, settings)
    if success and json then
        local file, err = io.open(self.settingsFile, "w")
        if file then
            local writeOk, writeErr = pcall(function()
                file:write(json)
                file:close()
            end)
            if not writeOk then
                print("[WM Error] Failed to write settings: " .. tostring(writeErr))
            end
        else
            print("[WM Error] Failed to open settings file for writing: " .. tostring(err))
        end
    elseif not success then
        print("[WM Error] Failed to encode settings: " .. tostring(json))
    end
end

-- API delegation methods
function obj:configure(config)
    return self.api:configure(config)
end

function obj:bindHotkeys(mapping)
    return self.api:bindHotkeys(mapping)
end

function obj:start()
    return self.api:start()
end

return obj
