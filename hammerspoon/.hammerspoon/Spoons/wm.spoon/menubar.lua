-- LaWM Menubar Module
-- Displays workspace indicators in the menubar

local Menubar = {}
Menubar.__index = Menubar

function Menubar:new(spoon)
    local obj = setmetatable({}, self)
    obj.spoon = spoon
    obj.menubarItem = nil
    obj.canvas = nil
    return obj
end

function Menubar:start()
    if not self.spoon.config.menubar.enabled then return end

    -- Create menubar item
    self.menubarItem = hs.menubar.new()
    if not self.menubarItem then return end

    -- Set click callback to show workspace menu
    self.menubarItem:setClickCallback(function()
        self:showMenu()
    end)

    -- Initial update
    self:update()
end

function Menubar:stop()
    if self.menubarItem then
        self.menubarItem:delete()
        self.menubarItem = nil
    end
end

function Menubar:update()
    if not self.menubarItem then return end

    local wm = self.spoon.workspaceManager
    if not wm then return end

    local config = self.spoon.config.menubar
    local current = wm.current

    -- Get layout info for color
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    local tilingEnabled = self.spoon.core:isTilingEnabled()
    local modeColors = self.spoon.config.modeColors or {}

    -- Get layout color (used for current workspace and layout name)
    local layoutColor = modeColors[layout] or config.activeColor

    -- Workspace number symbols
    local filledNumbers = { "❶", "❷", "❸", "❹", "❺", "❻", "❼", "❽", "❾" } -- Current workspace
    local solidNumbers = { "➊", "➋", "➌", "➍", "➎", "➏", "➐", "➑", "➒" } -- Has windows
    local emptyNumbers = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨" } -- Empty

    local styledText = hs.styledtext.new("")

    for i = 1, 9 do
        local windowCount = wm:getWindowCount(i)
        local isCurrent = (i == current)
        local hasWindows = (windowCount > 0)

        local color, text
        if isCurrent then
            -- Current workspace uses layout color
            color = layoutColor
            text = filledNumbers[i]
        elseif hasWindows then
            color = config.hasWindowsColor
            text = solidNumbers[i]
        else
            color = config.inactiveColor
            text = emptyNumbers[i]
        end

        local segment = hs.styledtext.new(text, {
            color = color,
            font = { name = ".AppleSystemUIFont", size = 20 },
        })

        styledText = styledText .. segment

        -- Add small space between numbers (except last)
        if i < 9 then
            styledText = styledText .. hs.styledtext.new(" ", {
                font = { size = 6 },
            })
        end
    end

    -- Add layout name with layout color
    if layout then
        local layoutNames = {
            tile = "Tile",
            stack = "Stack",
            scroll = "Scroll"
        }
        local layoutName = layoutNames[layout] or layout

        -- Dim if tiling is off
        local displayColor = tilingEnabled and layoutColor or { red = 0.5, green = 0.5, blue = 0.5, alpha = 0.5 }
        local tilingIndicator = tilingEnabled and "" or " ○"

        local layoutText = hs.styledtext.new(" │ " .. layoutName .. tilingIndicator, {
            color = displayColor,
            font = { name = ".AppleSystemUIFont", size = 16 },
        })

        styledText = styledText .. layoutText
    end

    self.menubarItem:setTitle(styledText)
end

function Menubar:showMenu()
    local wm = self.spoon.workspaceManager
    if not wm then return end

    local menuItems = {}

    for i = 1, 9 do
        local windowCount = wm:getWindowCount(i)
        local isCurrent = (i == wm.current)

        local title = "Workspace " .. i
        if windowCount > 0 then
            title = title .. " (" .. windowCount .. " windows)"
        end
        if isCurrent then
            title = title .. " *"
        end

        table.insert(menuItems, {
            title = title,
            fn = function()
                self.spoon.api:focusWorkspace(i)
            end,
            checked = isCurrent,
        })
    end

    table.insert(menuItems, { title = "-" })

    -- Add layout info
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    local tilingEnabled = self.spoon.core:isTilingEnabled()

    table.insert(menuItems, {
        title = "Layout: " .. (layout or "unknown"):upper(),
        disabled = true,
    })

    table.insert(menuItems, {
        title = "Tiling: " .. (tilingEnabled and "ON" or "OFF"),
        fn = function()
            self.spoon.core:toggleTiling()
        end,
        checked = tilingEnabled,
    })

    self.menubarItem:setMenu(menuItems)
end

return Menubar
