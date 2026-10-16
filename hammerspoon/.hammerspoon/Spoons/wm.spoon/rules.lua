-- WM Rules
-- Decides how every window is managed: tiled, floating or ignored (plus optional workspace/geometry).
--
-- A rule is a table of matchers and actions:
--
--   { app_name = "Finder", action = "float" }
--   { app_id = "com.google.*", workspace = 2 }
--   { title = "*Preferences*", action = "float" }
--   { app_id = "com.apple.finder", title = "Copy*", action = "float", dimensions = { 500, 200 }, center = true }
--
-- Matchers (all given matchers must match; a list means "any of"):
--   app_name, app_id (bundle id), title, ax_id (AXIdentifier), subrole ("AX" prefix optional)
--       glob patterns: * and ? wildcards, case-insensitive; the value "none" matches a missing/empty value
--   fullscreen_button, close_button, minimize_button, zoom_button
--       exists | none | enabled | disabled
--
-- Actions:
--   action     = "float" | "tile" | "ignore"   (ignore: never managed, e.g. popups)
--   workspace  = 1..9                          (send new windows to this workspace)
--   dimensions = { width, height }             (floating windows only)
--   position   = { x, y }                      (floating windows only)
--   center     = true                          (floating windows only)
--
-- Every matching rule is applied in order and later rules override earlier ones, so user rules
-- (which come after the defaults) can override any default.

local Rules = {}
Rules.__index = Rules

-- Cheap matchers first so expensive accessibility lookups only run when needed
local TEXT_MATCHERS = { "app_name", "app_id", "title", "subrole", "ax_id" }
local BUTTON_MATCHERS = {
    fullscreen_button = "AXFullScreenButton",
    close_button = "AXCloseButton",
    minimize_button = "AXMinimizeButton",
    zoom_button = "AXZoomButton",
}
local BUTTON_ORDER = { "fullscreen_button", "close_button", "minimize_button", "zoom_button" }
local BUTTON_STATES = { exists = true, none = true, enabled = true, disabled = true }
local ACTIONS = { float = true, tile = true, ignore = true }

local KNOWN_KEYS = { action = true, workspace = true, dimensions = true, position = true, center = true }
for _, k in ipairs(TEXT_MATCHERS) do KNOWN_KEYS[k] = true end
for k in pairs(BUTTON_MATCHERS) do KNOWN_KEYS[k] = true end

--------------------------------------------------------------------------------
-- Matching helpers
--------------------------------------------------------------------------------

-- "AXDialog" and "Dialog" are the same subrole
local function normalize(key, text)
    text = text:lower()
    if key == "subrole" then text = text:gsub("^ax", "") end
    return text
end

local function globToPattern(glob)
    local escaped = glob:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0")
    escaped = escaped:gsub("%*", ".*"):gsub("%?", ".")
    return "^" .. escaped .. "$"
end

local function asList(value)
    if type(value) == "table" then return value end
    return { value }
end

local function textMatches(compiled, value)
    local missing = (value == nil or value == "")
    for _, p in ipairs(compiled) do
        if p.none then
            if missing then return true end
        elseif not missing and normalize(p.key, value):match(p.pattern) then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Window facts (looked up lazily, once per evaluation)
--------------------------------------------------------------------------------

local NIL = {}
local Facts = {}
Facts.__index = Facts

local function newFacts(win)
    return setmetatable({ win = win, cache = {} }, Facts)
end

local function cached(self, key, fetch)
    local v = self.cache[key]
    if v == nil then
        local ok, value = pcall(fetch)
        v = (ok and value ~= nil) and value or NIL
        self.cache[key] = v
    end
    if v == NIL then return nil end
    return v
end

function Facts:ax()
    return cached(self, "_ax", function() return hs.axuielement.windowElement(self.win) end)
end

function Facts:get(key)
    local win = self.win
    if key == "app_name" then
        return cached(self, key, function() return win:application():name() end)
    elseif key == "app_id" then
        return cached(self, key, function() return win:application():bundleID() end)
    elseif key == "title" then
        return cached(self, key, function() return win:title() end)
    elseif key == "subrole" then
        return cached(self, key, function() return win:subrole() end)
    elseif key == "ax_id" then
        return cached(self, key, function()
            local ax = self:ax()
            return ax and ax:attributeValue("AXIdentifier")
        end)
    end
end

-- "none" | "enabled" | "disabled", or nil when the accessibility lookup itself failed
function Facts:buttonState(key)
    return cached(self, key, function()
        local ax = self:ax()
        if not ax then return nil end
        local button = ax:attributeValue(BUTTON_MATCHERS[key])
        if not button then return "none" end
        if button:attributeValue("AXEnabled") == false then return "disabled" end
        return "enabled"
    end)
end

local function buttonMatches(patterns, state)
    if state == nil then return false end -- Unknown: never match on a failed lookup
    for _, p in ipairs(patterns) do
        if p == state or (p == "exists" and state ~= "none") then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- Rule compilation
--------------------------------------------------------------------------------

local function compileRule(rule, label)
    if type(rule) ~= "table" then return nil, label .. " must be a table" end

    for key in pairs(rule) do
        if not KNOWN_KEYS[key] then
            return nil, label .. ": unknown key '" .. tostring(key) .. "'"
        end
    end

    local compiled = { source = rule, text = {}, buttons = {} }

    for _, key in ipairs(TEXT_MATCHERS) do
        if rule[key] ~= nil then
            local patterns = {}
            for _, glob in ipairs(asList(rule[key])) do
                if type(glob) ~= "string" then return nil, label .. ": " .. key .. " must be a string or list of strings" end
                if glob:lower() == "none" then
                    patterns[#patterns + 1] = { none = true }
                else
                    patterns[#patterns + 1] = { key = key, pattern = globToPattern(normalize(key, glob)) }
                end
            end
            compiled.text[#compiled.text + 1] = { key = key, patterns = patterns }
        end
    end

    for _, key in ipairs(BUTTON_ORDER) do
        if rule[key] ~= nil then
            local states = {}
            for _, state in ipairs(asList(rule[key])) do
                if not BUTTON_STATES[state] then
                    return nil, label .. ": " .. key .. " must be exists, none, enabled or disabled"
                end
                states[#states + 1] = state
            end
            compiled.buttons[#compiled.buttons + 1] = { key = key, states = states }
        end
    end

    if rule.action ~= nil and not ACTIONS[rule.action] then
        return nil, label .. ": action must be float, tile or ignore"
    end
    if rule.workspace ~= nil and not (type(rule.workspace) == "number" and rule.workspace >= 1 and rule.workspace <= 9) then
        return nil, label .. ": workspace must be 1-9"
    end
    for _, key in ipairs({ "dimensions", "position" }) do
        local v = rule[key]
        if v ~= nil and not (type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number") then
            return nil, label .. ": " .. key .. " must be { number, number }"
        end
    end

    return compiled
end

local function ruleMatches(compiled, facts)
    for _, m in ipairs(compiled.text) do
        if not textMatches(m.patterns, facts:get(m.key)) then return false end
    end
    for _, m in ipairs(compiled.buttons) do
        if not buttonMatches(m.states, facts:buttonState(m.key)) then return false end
    end
    return true
end

--------------------------------------------------------------------------------
-- Rules object
--------------------------------------------------------------------------------

function Rules:new(spoon)
    return setmetatable({ spoon = spoon, compiled = nil }, self)
end

--- Force the rule list to be rebuilt from the config (also reports invalid rules)
function Rules:invalidate()
    self.compiled = nil
    self:getRules()
end

function Rules:getRules()
    if self.compiled then return self.compiled end

    local config = self.spoon.config
    local sources = {}
    for _, group in ipairs({
        { "defaultRules", config.defaultRules },
        { "rules",        config.rules },
    }) do
        for i, rule in ipairs(group[2] or {}) do
            sources[#sources + 1] = { rule = rule, label = group[1] .. "[" .. i .. "]" }
        end
    end

    self.compiled = {}
    for _, s in ipairs(sources) do
        local compiled, err = compileRule(s.rule, s.label)
        if compiled then
            compiled.label = s.label
            self.compiled[#self.compiled + 1] = compiled
        else
            print("[WM Rule Error] " .. err .. " (rule skipped)")
        end
    end
    return self.compiled
end

--- Decide how a window is managed.
--- Returns { manage = "tile"|"float"|"ignore", workspace, dimensions, position, center, rule = label }
function Rules:classify(win)
    local result = { manage = "tile" }

    -- Not a real, usable window: nothing a rule could sensibly do with it
    local ok, id = pcall(function() return win and win:id() end)
    if not ok or not id then return { manage = "ignore", rule = "(no window id)" } end
    local visOk, visible = pcall(function() return win:isVisible() or win:isMinimized() end)
    if not visOk or not visible then return { manage = "ignore", rule = "(not visible)" } end

    local facts = newFacts(win)
    for _, compiled in ipairs(self:getRules()) do
        if ruleMatches(compiled, facts) then
            local rule = compiled.source
            if rule.action then result.manage = rule.action end
            if rule.workspace then result.workspace = rule.workspace end
            if rule.dimensions then result.dimensions = rule.dimensions end
            if rule.position then result.position = rule.position end
            if rule.center then result.center = true end
            result.rule = compiled.label
        end
    end

    return result
end

--- Everything a rule can match on, for the window-info display and for writing rules
function Rules:describe(win)
    local facts = newFacts(win)
    local info = {}
    for _, key in ipairs(TEXT_MATCHERS) do info[key] = facts:get(key) end
    for _, key in ipairs(BUTTON_ORDER) do info[key] = facts:buttonState(key) end
    return info
end

--- A rule table (as Lua source) that matches this window, ready to paste into a config
function Rules:snippet(win)
    local info = self:describe(win)
    local parts = {}
    if info.app_id then parts[#parts + 1] = string.format("app_id = %q", info.app_id) end
    if info.subrole then parts[#parts + 1] = string.format("subrole = %q", (info.subrole:gsub("^AX", ""))) end
    if info.title and info.title ~= "" then parts[#parts + 1] = string.format("title = %q", info.title) end
    parts[#parts + 1] = 'action = "float"'
    return "{ " .. table.concat(parts, ", ") .. " }"
end

return Rules
