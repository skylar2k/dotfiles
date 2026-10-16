-- WM (dwm-style tags)
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
        -- Only real windows are managed: everything else (popups, sheets, notification banners, ...)
        -- is ignored unless a later rule re-enables it by matching its subrole.
        { action = "ignore" },
        { subrole = "StandardWindow",             action = "tile" },
        { subrole = { "Dialog", "SystemDialog" }, action = "float", center = true },
        { subrole = "FloatingWindow",             action = "float" },

        -- Fixed-size windows (settings, calculators, progress panels) have no fullscreen button
        -- and can't be tiled sensibly
        { subrole = "StandardWindow", fullscreen_button = "none", action = "float" },

        -- Never managed, whatever they look like: macOS system UI (menu bar dropdowns, notifications,
        -- Spotlight, ...) and Hammerspoon's own windows (chooser, console). Keep these last so they win.
        {
            app_id = { "org.hammerspoon.Hammerspoon", "com.apple.controlcenter", "com.apple.systemuiserver",
                "com.apple.notificationcenterui", "com.apple.Spotlight", "com.apple.loginwindow",
                "com.apple.dock", "com.apple.WindowManager" },
            action = "ignore"
        },
        { app_name = "MenuBarAgent", action = "ignore" },
    },
    rules = {},

    newWindow = "master",       -- Where new windows go: "master" (dwm's attach) or "last"
    spawnFocusTimeout = 5,      -- Seconds after a spawn in which the next new window gets focus
    scratchpad = { width = 0.6, height = 0.6 }, -- Size of the scratchpad, as a fraction of the screen
    scroll = { wrap = false },  -- Scrolling past the first/last column wraps around

    -- Programs for spawn_<name> hotkeys: a shell command string, or { program, arg, ... }
    commands = {},

    -- Consolidated sub-configs
    resizing = { step = 0.05, minRatio = 0.15 },
    timing = { layoutUpdateDelay = 0.08, spaceChangeDelay = 0.12, initialSetupDelay = 0.15, ruleRecheckDelay = 0.4 },
    focusedWindowIndicator = { width = 50, height = 4, opacity = 0.9, borderRadius = 2 },
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

    -- Menubar tag indicator
    menubar = {
        enabled = true,
        activeColor = { red = 0.4, green = 0.8, blue = 0.4 },
        inactiveColor = { red = 0.5, green = 0.5, blue = 0.5 },
        hasWindowsColor = { red = 0.8, green = 0.8, blue = 0.8 },
    }
}

-- Constants and initial state
obj.layouts = { "tile", "scroll", "stack" }
obj.settingsFile = (hs.configdir or (os.getenv("HOME") .. "/.hammerspoon")) .. "/wm_settings.json"
obj.state = {
    windows = {},          -- Tiled windows in view, in layout order (rebuilt on every layout pass)
    floatingSteps = {},
    tileEnabled = true,    -- Global tiling toggle (persisted)
    alertUUID = nil,
    ready = false          -- Set once startup is complete; settings are never written before this
}

-- Load modules
local Core = dofile(hs.spoons.resourcePath("core.lua"))
local UI = dofile(hs.spoons.resourcePath("ui.lua"))
local Helpers = dofile(hs.spoons.resourcePath("helpers.lua"))
local API = dofile(hs.spoons.resourcePath("api.lua"))
local Tags = dofile(hs.spoons.resourcePath("tags.lua"))
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
    self.tags = Tags:new(self)
    self.layoutsModule = Layouts:new(self)
    self.menubar = Menubar:new(self)

    self:loadSettings()
    return self
end

-- Layout of the current tag (dwm pertag: each tag has its own layout)
function obj:getLayoutIndex()
    return self.tags:getPertag().layout or 1
end

function obj:setLayoutIndex(layoutIndex)
    self.tags:getPertag().layout = layoutIndex
end

-- Name of the layout ("tile" | "scroll" | "stack") of the current tag
function obj:getCurrentLayoutName()
    return self.layouts[self:getLayoutIndex()]
end

function obj:updateLayout()
    self.core:updateLayout()
    self:saveSettings()
end

-- Settings management
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

    if type(settings.tileEnabled) == "boolean" then self.state.tileEnabled = settings.tileEnabled end

    -- Floating step ids come back from JSON as strings
    for k, v in pairs(settings.floatingSteps or {}) do
        self.state.floatingSteps[tonumber(k)] = v
    end

    -- The tag session is restored when the spoon starts (see API:start)
    self.state.pendingTags = settings.tags

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
    -- Floating step ids become strings for JSON
    local floatingSteps = {}
    for id, v in pairs(self.state.floatingSteps) do floatingSteps[tostring(id)] = v end

    local settings = {
        tileEnabled = self.state.tileEnabled,
        floatingSteps = floatingSteps,
        tags = self.tags:serialize(),

        -- Config (only user-modifiable parts)
        config = {
            resizing = self.config.resizing,
            timing = self.config.timing,
            focusedWindowIndicator = self.config.focusedWindowIndicator,
            alerts = self.config.alerts,
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
