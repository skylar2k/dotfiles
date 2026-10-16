-- WM UI
local UI = {}
UI.__index = UI

function UI:new(spoon)
    local o = setmetatable({}, self)
    o.spoon = spoon
    o.focusedWindowCanvas = nil
    o.stackIndicatorsCanvas = nil
    return o
end

function UI:updateFocusedWindowIndicator()
    -- Clean up existing indicator safely
    if self.focusedWindowCanvas then
        pcall(function() self.focusedWindowCanvas:delete() end)
        self.focusedWindowCanvas = nil
    end

    -- Check if indicator is enabled
    local indicatorConfig = self.spoon.config.focusedWindowIndicator
    if indicatorConfig and indicatorConfig.enabled == false then return end

    local layoutIndex = self.spoon:getLayoutForCurrentSpace()
    if not layoutIndex then return end

    local layout = self.spoon.layouts[layoutIndex]
    if not layout or layout == "stack" then return end

    local win = hs.window.focusedWindow()
    if not win then return end

    -- Only tiled windows of the current workspace get an indicator
    local winId = self.spoon.helpers:getWindowId(win)
    if not winId or not self.spoon.workspaceManager:isTiled(winId) then return end

    local ok2, frame = pcall(function() return win:frame() end)
    if not ok2 or not frame then return end

    local color = self.spoon.config.modeColors[layout]
    if not color then return end

    -- Create a small indicator at the bottom center of the window
    local indicatorConfig = self.spoon.config.focusedWindowIndicator
    if not indicatorConfig then return end

    local indicatorWidth = indicatorConfig.width or 50
    local indicatorHeight = indicatorConfig.height or 4
    local x = frame.x + (frame.w - indicatorWidth) / 2
    local y = frame.y + frame.h - indicatorHeight

    local canvasOk, canvas = pcall(function()
        return hs.canvas.new({
            x = x,
            y = y,
            w = indicatorWidth,
            h = indicatorHeight
        })
    end)

    if not canvasOk or not canvas then return end

    self.focusedWindowCanvas = canvas

    pcall(function()
        self.focusedWindowCanvas:level(hs.canvas.windowLevels.overlay)
        self.focusedWindowCanvas:appendElements({
            type = "rectangle",
            action = "fill",
            fillColor = {
                red = color.red or 0.5,
                green = color.green or 0.5,
                blue = color.blue or 0.5,
                alpha = indicatorConfig.opacity or 0.9
            },
            roundedRectRadii = {
                xRadius = indicatorConfig.borderRadius or 2,
                yRadius = indicatorConfig.borderRadius or 2
            }
        })
        self.focusedWindowCanvas:show()
    end)
end

function UI:updateAll()
    self:updateFocusedWindowIndicator()
    -- Cleanup stack indicators if they exist
    if self.stackIndicatorsCanvas then
        pcall(function() self.stackIndicatorsCanvas:delete() end)
        self.stackIndicatorsCanvas = nil
    end
end

function UI:cleanup()
    if self.focusedWindowCanvas then
        pcall(function() self.focusedWindowCanvas:delete() end)
        self.focusedWindowCanvas = nil
    end
    if self.stackIndicatorsCanvas then
        pcall(function() self.stackIndicatorsCanvas:delete() end)
        self.stackIndicatorsCanvas = nil
    end
end

return UI
