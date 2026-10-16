-- WM UI
local UI = {}
UI.__index = UI

function UI:new(spoon)
    local o = setmetatable({}, self)
    o.spoon = spoon
    o.canvas = nil -- The focus indicator: created once, then moved and recolored
    return o
end

local function hideIndicator(self)
    if self.canvas then pcall(function() self.canvas:hide() end) end
end

local function ensureCanvas(self, frame)
    if self.canvas then return self.canvas end
    local ok, canvas = pcall(hs.canvas.new, frame)
    if not ok or not canvas then return nil end
    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:appendElements({ type = "rectangle", action = "fill" })
    self.canvas = canvas
    return canvas
end

--- A small bar at the bottom center of the focused window, in the color of the current layout
function UI:updateFocusedWindowIndicator()
    local spoon = self.spoon
    local config = spoon.config.focusedWindowIndicator
    if not config or config.enabled == false then return hideIndicator(self) end

    local layout = spoon:getCurrentLayoutName()
    if not layout or layout == "stack" then return hideIndicator(self) end

    local win = hs.window.focusedWindow()
    local winId = win and spoon.helpers:getWindowId(win)
    if not winId or not spoon.tags:isTiled(winId) then return hideIndicator(self) end -- Only tiled windows in view

    local ok, frame = pcall(win.frame, win)
    local color = spoon.config.modeColors[layout]
    if not ok or not frame or not color then return hideIndicator(self) end

    local width, height = config.width or 50, config.height or 4
    local rect = {
        x = frame.x + (frame.w - width) / 2,
        y = frame.y + frame.h - height,
        w = width,
        h = height,
    }

    local canvas = ensureCanvas(self, rect)
    if not canvas then return end

    local radius = config.borderRadius or 2
    pcall(function()
        canvas:frame(rect)
        canvas[1].fillColor = {
            red = color.red or 0.5,
            green = color.green or 0.5,
            blue = color.blue or 0.5,
            alpha = config.opacity or 0.9,
        }
        canvas[1].roundedRectRadii = { xRadius = radius, yRadius = radius }
        canvas:show()
    end)
end

function UI:updateAll()
    self:updateFocusedWindowIndicator()
end

function UI:cleanup()
    if self.canvas then
        pcall(function() self.canvas:delete() end)
        self.canvas = nil
    end
end

return UI
