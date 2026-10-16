-- WM Menubar Module
-- Displays the tags in the menubar (display only: no menu, no click handling, so clicking it can
-- never move focus or change the view)

local Menubar = {}
Menubar.__index = Menubar

-- In view (filled) / has windows (solid) / empty (outline)
local FILLED = { "❶", "❷", "❸", "❹", "❺", "❻", "❼", "❽", "❾" }
local SOLID = { "➊", "➋", "➌", "➍", "➎", "➏", "➐", "➑", "➒" }
local EMPTY = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨" }

local LAYOUT_NAMES = { tile = "Tile", stack = "Stack", scroll = "Scroll" }
local DIMMED = { red = 0.5, green = 0.5, blue = 0.5, alpha = 0.5 }

function Menubar:new(spoon)
    return setmetatable({ spoon = spoon, menubarItem = nil, lastKey = nil }, self)
end

function Menubar:start()
    if not self.spoon.config.menubar.enabled then return end

    self.menubarItem = hs.menubar.new()
    if not self.menubarItem then return end

    self.lastKey = nil
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

    local spoon = self.spoon
    local tags = spoon.tags
    if not tags then return end

    local config = spoon.config.menubar
    local view, occupied = tags:viewMask(), tags:occupied()
    local layout = spoon:getCurrentLayoutName()
    local tilingEnabled = spoon.core:isTilingEnabled()

    -- Redraw only when something visible changed: layout passes call this very often
    local zoomed = tags:getZoomed() ~= nil
    local key = string.format("%d|%d|%s|%s|%s", view, occupied, tostring(layout), tostring(tilingEnabled), tostring(zoomed))
    if key == self.lastKey then return end
    self.lastKey = key

    local layoutColor = (spoon.config.modeColors or {})[layout] or config.activeColor
    local font = { name = ".AppleSystemUIFont", size = 20 }

    local styledText = hs.styledtext.new("")
    for i = 1, tags.COUNT do
        local bit = tags.bit(i)
        local color, text
        if view & bit ~= 0 then
            color, text = layoutColor, FILLED[i]
        elseif occupied & bit ~= 0 then
            color, text = config.hasWindowsColor, SOLID[i]
        else
            color, text = config.inactiveColor, EMPTY[i]
        end

        styledText = styledText .. hs.styledtext.new(text, { color = color, font = font })
        if i < tags.COUNT then
            styledText = styledText .. hs.styledtext.new(" ", { font = { size = 6 } })
        end
    end

    if layout then
        local displayColor = tilingEnabled and layoutColor or DIMMED
        styledText = styledText .. hs.styledtext.new(
            " │ " .. (LAYOUT_NAMES[layout] or layout) .. (tilingEnabled and "" or " ○") .. (zoomed and " ⤢" or ""),
            { color = displayColor, font = { name = ".AppleSystemUIFont", size = 16 } })
    end

    self.menubarItem:setTitle(styledText)
end

return Menubar
