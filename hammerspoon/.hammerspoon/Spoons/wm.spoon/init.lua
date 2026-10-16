-- WM
local obj = {}
obj.__index = obj

-- Configuration with consolidated structure
obj.config = {
    debug = false, -- Enable debug logging
    gap = 8,

    -- Window rules (see rules.lua). Rules are applied in order and later ones win, so `rules`
    -- (yours, set via configure) can override anything in `defaultRules`.
    -- Set `defaultRules = {}` in configure() to start from a clean slate.
    defaultRules = {
        -- Only real windows are ever managed. Everything else (notification banners, popups, sheets,
        -- tooltips, Hammerspoon's own alerts, windows without a subrole, ...) is ignored. A later
        -- rule can only re-enable a window by matching its subrole.
        { action = "ignore" },
        { subrole = "StandardWindow",             action = "tile" },
        { subrole = { "Dialog", "SystemDialog" }, action = "float", center = true },
        { subrole = "FloatingWindow",             action = "float" },

        -- macOS system UI is never managed: menu bar dropdowns (Wi-Fi, Control Center, clock), notifications,
        -- Spotlight, the login window. Must come after the subrole rules above so it wins.
        {
            app_id = { "com.apple.controlcenter", "com.apple.systemuiserver", "com.apple.notificationcenterui",
                "com.apple.Spotlight", "com.apple.loginwindow", "com.apple.dock", "com.apple.WindowManager" },
            action = "ignore"
        },
        {
            app_name = { "MenuBarAgent", "Control Center", "SystemUIServer", "Notification Center", "Spotlight",
                "Dock", "WindowManager", "loginwindow" },
            action = "ignore"
        },

        -- Standard windows without a fullscreen button are fixed-size panels (settings, progress, ...)
        { subrole = "StandardWindow", fullscreen_button = "none",             action = "float" },

        -- Settings windows
        {
            subrole = "StandardWindow",
            title = { "Settings", "Preferences", "Settings…", "Preferences…", "* Settings", "* Preferences" },
            action = "float"
        },

        -- Utility apps that make no sense tiled
        {
            subrole = "StandardWindow",
            app_name = { "System Settings", "System Preferences", "Activity Monitor", "Console",
                "Disk Utility", "Keychain Access", "Calculator" },
            action = "float"
        },
        { subrole = "StandardWindow", app_id = "org.hammerspoon.Hammerspoon", action = "float" },
    },
    rules = {},
    usePerSpaceLayouts = true,

    -- Consolidated sub-configs
    resizing = { step = 0.05, minRatio = 0.15, maxRatio = 0.85 },
    timing = { layoutUpdateDelay = 0.08, spaceChangeDelay = 0.12, initialSetupDelay = 0.15, windowLockDuration = 0.4, ruleRecheckDelay = 0.4 },
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
obj.settingsFile = (hs.configdir or (os.getenv("HOME") .. "/.hammerspoon")) .. "/wm_settings.json"
obj.state = {
    currentLayout = 1,
    windows = {},
    floatingWindows = {},
    floatingSteps = {},
    splitRatios = {},
    tileEnabled = true, -- Global tiling toggle (persisted)
    splitDirections = {},
    windowTree = {},
    spaceLayouts = {},
    spaceWindowOrder = {},
    layoutChanged = false,
    ignoreNextUpdate = false,
    alertUUID = nil,
    fullscreenWindows = {},
    ready = false -- Set once startup is complete; settings are never written before this
}

-- Load modules
local Core = dofile(hs.spoons.resourcePath("core.lua"))
local UI = dofile(hs.spoons.resourcePath("ui.lua"))
local Helpers = dofile(hs.spoons.resourcePath("helpers.lua"))
local API = dofile(hs.spoons.resourcePath("api.lua"))
local WorkspaceManager = dofile(hs.spoons.resourcePath("workspace_manager.lua"))
local Layouts = dofile(hs.spoons.resourcePath("layouts.lua"))
local Rules = dofile(hs.spoons.resourcePath("rules.lua"))
local Menubar = dofile(hs.spoons.resourcePath("menubar.lua"))

function obj:hexToColor(hex, alpha)
    if type(hex) == "table" then return hex end

    local digits = tostring(hex):gsub("#", "")
    local r, g, b = tonumber(digits:sub(1, 2), 16), tonumber(digits:sub(3, 4), 16), tonumber(digits:sub(5, 6), 16)
    if #digits ~= 6 or not (r and g and b) then
        print("[WM Config Warning] Invalid hex color '" .. tostring(hex) .. "', using gray")
        return { red = 0.5, green = 0.5, blue = 0.5, alpha = alpha or 1.0 }
    end
    return { red = r / 255, green = g / 255, blue = b / 255, alpha = alpha or 1.0 }
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
    self.rules = Rules:new(self)
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

-- Name of the layout ("tile" | "scroll" | "stack") for the current workspace
function obj:getCurrentLayoutName()
    return self.layouts[self:getLayoutForCurrentSpace()]
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
-- Saved window order is tracked per workspace (not per macOS Space): workspaces share one Space
function obj:getOrderKey()
    local wm = self.workspaceManager
    return wm and ("ws" .. wm.current) or self:getCurrentSpaceID()
end

function obj:saveWindowOrderForCurrentSpace()
    local orderKey = self:getOrderKey()
    if not orderKey or not self.state.windows then return end

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

    self.state.spaceWindowOrder[orderKey] = windowOrder
end

function obj:restoreWindowOrderForCurrentSpace()
    local orderKey = self:getOrderKey()
    if not orderKey or not self.state.spaceWindowOrder[orderKey] then return false end

    local savedOrder = self.state.spaceWindowOrder[orderKey]

    local currentWindows = self.workspaceManager:getWindowsForLayout()

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
    if not file then return end -- First run: nothing to load

    local content = file:read("*all")
    file:close()
    if not content or content == "" then return end

    local success, settings = pcall(hs.json.decode, content)
    if not success or type(settings) ~= "table" then
        print("[WM Error] Ignoring unreadable settings file: " .. tostring(self.settingsFile))
        return
    end

    -- Load state (excluding runtime-only fields)
    local excludedStateKeys = { alertUUID = true, floatingWindows = true, floatingSteps = true, ready = true }
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

    if type(settings.tileEnabled) == "boolean" then self.state.tileEnabled = settings.tileEnabled end

    -- Workspace assignments are restored when the spoon starts (see API:start)
    self.state.pendingWorkspaces = settings.workspaces

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

-- Debounced: layout updates fire in bursts, and writing the file each time is wasteful
function obj:saveSettings(immediate)
    if not self.state.ready then return end
    if immediate then
        if self._saveTimer then
            self._saveTimer:stop(); self._saveTimer = nil
        end
        return self:writeSettings()
    end
    if self._saveTimer then self._saveTimer:stop() end
    self._saveTimer = hs.timer.doAfter(0.3, function()
        self._saveTimer = nil
        self:writeSettings()
    end)
end

function obj:writeSettings()
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
        tileEnabled = self.state.tileEnabled,
        splitRatios = self.state.splitRatios,
        splitDirections = self.state.splitDirections,
        floatingWindows = convertIdsToStrings(self.state.floatingWindows),
        floatingSteps = convertIdsToStrings(self.state.floatingSteps),
        spaceLayouts = self.state.spaceLayouts,
        spaceWindowOrder = self.state.spaceWindowOrder,
        workspaceLayouts = workspaceLayouts,
        workspaces = self.workspaceManager and self.workspaceManager:serialize() or nil,

        -- Config (only user-modifiable parts)
        config = {
            usePerSpaceLayouts = self.config.usePerSpaceLayouts,
            resizing = self.config.resizing,
            timing = self.config.timing,
            focusedWindowIndicator = self.config.focusedWindowIndicator,
            alerts = self.config.alerts,
            stackIndicators = self.config.stackIndicators
        }
    }

    local success, json = pcall(hs.json.encode, settings)
    if not success or not json then
        print("[WM Error] Failed to encode settings: " .. tostring(json))
        return
    end

    -- Write to a temp file and rename so a crash mid-write can't corrupt the settings
    local tmpPath = self.settingsFile .. ".tmp"
    local file, err = io.open(tmpPath, "w")
    if not file then
        print("[WM Error] Failed to open settings file for writing: " .. tostring(err))
        return
    end
    local writeOk, writeErr = pcall(file.write, file, json)
    file:close()
    if not writeOk then
        print("[WM Error] Failed to write settings: " .. tostring(writeErr))
        os.remove(tmpPath)
        return
    end
    local renamed, renameErr = os.rename(tmpPath, self.settingsFile)
    if not renamed then
        print("[WM Error] Failed to replace settings file: " .. tostring(renameErr))
    end
end

-- API delegation methods
function obj:configure(config)
    return self.api:configure(config)
end

function obj:addRule(rule)
    return self.api:addRule(rule)
end

function obj:bindHotkeys(mapping)
    return self.api:bindHotkeys(mapping)
end

function obj:start()
    return self.api:start()
end

function obj:stop()
    self:saveSettings(true)
    return self.api:stop()
end

return obj
