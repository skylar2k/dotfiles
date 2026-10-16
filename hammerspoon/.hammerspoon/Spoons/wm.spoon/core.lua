-- WM Core Functions
local Core = {}
Core.__index = Core

function Core:new(spoon) return setmetatable({ spoon = spoon }, self) end

-- Focused window and its id, or nil if there is none / the id can't be read
function Core:getFocusedWindow()
    local win = hs.window.focusedWindow()
    if not win then return nil end
    local ok, id = pcall(function() return win:id() end)
    if not ok or not id then return nil end
    return win, id
end

-- Focused window that may be freely positioned (tiling off or window floating), plus main screen frame.
-- Shows an alert and returns nil otherwise.
function Core:getFloatingTarget()
    local win, id = self:getFocusedWindow()
    if not win then return nil end

    if not self:isWindowFloating(id) then
        self:showAlert("Window is tiled"); return nil
    end

    local mainScreen = hs.screen.mainScreen()
    if not mainScreen then return nil end
    return win, id, mainScreen:frame()
end

-- Alert Management
function Core:showAlert(message)
    if not self.spoon.config.alerts.enabled then return end
    if self.spoon.state.alertUUID then hs.alert.closeSpecific(self.spoon.state.alertUUID) end
    local c = self.spoon.config.alerts
    local cfg = {
        strokeWidth = c.strokeWidth,
        fillColor = c.fillColor,
        textColor = c.textColor,
        textSize = c.textSize,
        radius = c.radius,
        fadeInDuration = c.fadeIn,
        fadeOutDuration = c.fadeOut
    }
    if c.position == "bottom" then cfg.atScreenEdge = 2 end
    self.spoon.state.alertUUID = hs.alert.show(message, cfg, c.duration)
end

-- Toggle Tiling On/Off
function Core:toggleTiling()
    self.spoon.state.tileEnabled = not self.spoon.state.tileEnabled

    if self.spoon.state.tileEnabled then
        self:showAlert("Tiling ON")
        self:updateLayout()
    else
        self:showAlert("Tiling OFF")
        -- Clear UI indicators when tile is off
        if self.spoon.ui then
            self.spoon.ui:cleanup()
        end
    end

    -- Update menubar
    if self.spoon.menubar then
        self.spoon.menubar:update()
    end

    self.spoon:saveSettings()
end

-- Check if tile is enabled
function Core:isTilingEnabled()
    return self.spoon.state.tileEnabled ~= false
end

-- Helper Functions
function Core:getWindowIndex(winId)
    for i, w in ipairs(self.spoon.state.windows) do if w:id() == winId then return i end end
end

-- Unified Resize Function (works across all layouts)
function Core:resizeFocusedWindow(direction)
    local win = hs.window.focusedWindow()
    if not win then return end

    local ok, winId = pcall(function() return win:id() end)
    if not ok or not winId then return end

    -- Skip if window is floating
    if self.spoon.tags:isFloating(winId) then return end

    local layout = self.spoon:getCurrentLayoutName()

    -- Tiling layout: left/right resizes columns, up/down resizes rows
    if layout == "tile" then
        if direction == "left" or direction == "right" then
            if self.spoon.layoutsModule and self.spoon.layoutsModule:tileResizeColumn(winId, direction) then
                self:updateLayout()
                self:showAlert("Column resized")
                self.spoon:saveSettings()
            end
        elseif direction == "up" or direction == "down" then
            if self.spoon.layoutsModule and self.spoon.layoutsModule:tileResizeRow(winId, direction) then
                self:updateLayout()
                self:showAlert("Row resized")
                self.spoon:saveSettings()
            end
        end
        return
    end

    -- Scroll: left/right scrolls viewport
    if layout == "scroll" then
        if direction == "left" then
            self:scrollLeft()
        elseif direction == "right" then
            self:scrollRight()
        end
        return
    end

    -- Stacking: resize does nothing for tiled windows
end

-- Window Management
function Core:updateLayout()
    local spoon = self.spoon

    -- A zoomed window fills the screen and nothing else is laid out: that keeps the layout state
    -- intact, so un-zooming puts every window back where it was
    local zoomed = spoon.tags:getZoomed()
    if zoomed then
        local screen = hs.screen.mainScreen()
        if screen then
            local f, gap = screen:frame(), spoon.config.zoomGap or 0
            spoon.layoutsModule:place(zoomed.win, { x = f.x + gap, y = f.y + gap, w = f.w - 2 * gap, h = f.h - 2 * gap })
            pcall(zoomed.win.raise, zoomed.win)
        end
        spoon.state.windows = spoon.tags:getVisibleTiled()
        spoon.ui:updateAll()
        spoon.state.layoutAppliedAt = hs.timer.secondsSinceEpoch()
        return
    end

    -- Skip layout if tile is disabled
    if not self:isTilingEnabled() then
        return
    end

    local windows = spoon.tags:getVisibleTiled()
    spoon.state.windows = windows

    local layouts = spoon.layoutsModule
    local screen = spoon.helpers:getScreenFrame()
    local layout = spoon:getCurrentLayoutName()
    if screen and layouts then
        if layout == "tile" then
            layouts:layout_tile(screen, windows)
        elseif layout == "stack" then
            layouts:layout_stack(screen, windows)
        elseif layout == "scroll" then
            layouts:layout_scroll(screen, windows)
        end
    end

    self:handleFloatingWindows()
    spoon.ui:updateAll()
    spoon.state.layoutAppliedAt = hs.timer.secondsSinceEpoch()
end

-- Keep floating windows of the tags in view above the tiled ones
function Core:handleFloatingWindows()
    for _, win in ipairs(self.spoon.tags:getVisibleFloating()) do
        pcall(win.raise, win)
    end
end

-- Balance and Window Operations
function Core:balanceLayout()
    local layout = self.spoon:getCurrentLayoutName()
    if layout == "tile" then
        if self.spoon.layoutsModule then
            self.spoon.layoutsModule:tileBalance()
        end
        self:showAlert("Balanced (60/40)")
    else
        self:showAlert("Tiling only"); return
    end
    self:updateLayout(); self.spoon:saveSettings()
end

--- Swap two tiled windows by their position in the layout list. The new order is kept in the tag
--- module, so it survives every later layout pass; the column structures follow along.
function Core:swapIndices(idx, targetIdx)
    local windows = self.spoon.state.windows
    local srcWin, dstWin = windows[idx], windows[targetIdx]
    if not srcWin or not dstWin then return false end
    local srcId, dstId = srcWin:id(), dstWin:id()

    windows[idx], windows[targetIdx] = dstWin, srcWin
    self.spoon.tags:setOrder(windows)

    local layouts = self.spoon.layoutsModule
    local layout = self.spoon:getCurrentLayoutName()
    if layout == "scroll" and layouts then
        -- Columns line up with the window list when every window has its own column
        local cols = layouts.scrollColumns
        if cols and idx <= #cols and targetIdx <= #cols then
            cols[idx], cols[targetIdx] = cols[targetIdx], cols[idx]
        end
    elseif layout == "tile" and layouts then
        local srcCol, srcRow = layouts:tileFindWindow(srcId)
        local dstCol, dstRow = layouts:tileFindWindow(dstId)
        if srcCol and dstCol then
            layouts.tileColumns[srcCol].windows[srcRow] = dstId
            layouts.tileColumns[dstCol].windows[dstRow] = srcId
        end
    end
    return true
end

-- Unified Swap Window (works across all tiled layouts)
function Core:swapWindow(direction)
    local win, winId = self:getFocusedWindow()
    if not win then
        self:showAlert("No focused window"); return
    end

    local layout = self.spoon:getCurrentLayoutName()

    local windows = self.spoon.state.windows
    if not windows or #windows < 2 then
        self:showAlert("Need 2+ windows"); return
    end

    -- For stack layout: swap is the same as cycle/rotate
    if layout == "stack" then
        if direction == "next" or direction == "right" or direction == "down" then
            self:focusNextWindow()
        else
            self:focusPrevWindow()
        end
        return
    end

    local idx = self:getWindowIndex(winId)
    if not idx then return end

    local targetIdx
    if direction == "next" or direction == "right" or direction == "down" then
        targetIdx = idx < #windows and idx + 1 or 1
    else
        targetIdx = idx > 1 and idx - 1 or #windows
    end

    self:swapIndices(idx, targetIdx)
    self:updateLayout()
    self:showAlert("Swapped")
    self.spoon:saveSettings()
end

-- Unified Move to Position (works across all tiled layouts)
function Core:moveToPosition(pos)
    local win, winId = self:getFocusedWindow()
    if not win then
        self:showAlert("No focused window"); return
    end

    -- Skip floating windows
    if self.spoon.tags:isFloating(winId) then
        self:showAlert("Window is floating"); return
    end

    local layout = self.spoon:getCurrentLayoutName()

    local windows = self.spoon.state.windows
    if #windows == 0 or pos < 1 or pos > #windows then
        self:showAlert("Invalid position"); return
    end
    local idx = self:getWindowIndex(winId)
    if not idx or idx == pos then
        self:showAlert("Already at " .. pos); return
    end
    local reordered, src = {}, 1
    for i = 1, #windows do
        if i == pos then
            reordered[i] = windows[idx]
        else
            if src == idx then src = src + 1 end; reordered[i] = windows[src]; src = src + 1
        end
    end
    self.spoon.tags:setOrder(reordered)

    -- For Scroll, rebuild columns based on new window order
    if layout == "scroll" and self.spoon.layoutsModule then
        local newCols = {}
        for _, w in ipairs(reordered) do
            local wOk, wId = pcall(function() return w:id() end)
            if wOk and wId then
                table.insert(newCols, { wId })
            end
        end
        self.spoon.layoutsModule.scrollColumns = newCols
    end

    self:updateLayout()
    self:showAlert("Position " .. pos)
    self.spoon:saveSettings()
end

-- Shows the focused window's matchable properties and prints a rule you can paste into your config
function Core:showWindowInfo()
    local win, winId = self:getFocusedWindow()
    if not win then
        self:showAlert("No focused window")
        return
    end

    local rules = self.spoon.rules
    local info = rules:describe(win)
    local result = rules:classify(win)
    local client = self.spoon.tags:getClient(winId)
    local title = info.title or ""

    print("[WM] window info: " .. hs.inspect(info))
    print("[WM] rule snippet: " .. rules:snippet(win))

    hs.alert.show(string.format(
        "%s (%s)\n%s\nsubrole: %s | ax_id: %s\nfullscreen: %s | close: %s\nmanaged as: %s%s | tags %s | id %s",
        info.app_name or "?", info.app_id or "?",
        #title > 40 and title:sub(1, 37) .. "..." or title,
        info.subrole or "none", info.ax_id or "none",
        info.fullscreen_button or "?", info.close_button or "?",
        result.manage, result.rule and (" via " .. result.rule) or "",
        client and (table.concat(self.spoon.tags.list(client.tags), "+") .. (client.sticky and " (sticky)" or "")) or "-", winId), 6)
end

function Core:toggleFloatingWindow()
    local win, winId = self:getFocusedWindow()
    if not win then return end

    local tags = self.spoon.tags

    -- Untracked windows (e.g. ignored by a rule) can be adopted by toggling them
    if not tags:getClient(winId) then tags:register(win, nil, { floating = false }) end

    if tags:isFloating(winId) then
        tags:setFloating(winId, false, true) -- manual: rules never override this
        self:showAlert("Tiled")
    else
        tags:setFloating(winId, true, true)
        -- Center the floating window
        local frameOk, f = pcall(function() return win:frame() end)
        local mainScreen = hs.screen.mainScreen()
        if frameOk and f and mainScreen then
            local s = mainScreen:frame()
            pcall(function()
                win:setFrame({ x = s.x + (s.w - f.w) / 2, y = s.y + (s.h - f.h) / 2, w = f.w, h = f.h })
            end)
        end
        self:showAlert("Floating")
    end

    self:updateLayout()
    self.spoon:saveSettings()
end

-- Unified Focus Window (works across all layouts)
function Core:focusNextWindow()
    self:focusWindowByDirection("next")
end

function Core:focusPrevWindow()
    self:focusWindowByDirection("prev")
end

function Core:focusWindowByDirection(direction)
    local windows = self.spoon.state.windows
    if #windows == 0 then return end


    local layout = self.spoon:getCurrentLayoutName()

    -- For stack layout: always rotate the stack instead of looking up current focus
    if layout == "stack" then
        local targetWin
        if direction == "next" then
            -- Rotate forward: move position 1 to end, everything shifts up
            if #windows >= 2 then
                targetWin = windows[1]
                table.remove(windows, 1)
                table.insert(windows, targetWin)
                -- Now window 2 is at position 1
                targetWin = windows[1]
            else
                targetWin = windows[1]
            end
        else
            -- Rotate backward: move last to position 1
            targetWin = windows[#windows]
            table.remove(windows, #windows)
            table.insert(windows, 1, targetWin)
        end

        self.spoon.tags:setOrder(windows)

        -- Focus events caused by the rotation itself must not be followed
        self.spoon.state.rotatingStack = true

        self:updateLayout()

        -- Focus and raise immediately
        if targetWin then
            pcall(function()
                targetWin:focus()
                targetWin:raise()
            end)
        end

        hs.timer.doAfter(0.2, function()
            self.spoon.state.rotatingStack = false
        end)
    else
        -- For other layouts: find current window and move to next/prev
        local cur = hs.window.focusedWindow()
        local idx = 1

        if cur then
            local ok, curId = pcall(function() return cur:id() end)
            if ok and curId then
                local i = self:getWindowIndex(curId)
                if i then
                    if direction == "next" then
                        idx = (i % #windows) + 1
                    else
                        idx = i > 1 and (i - 1) or #windows
                    end
                end
            end
        end

        pcall(function()
            windows[idx]:focus()
            windows[idx]:raise()
        end)
    end

    self.spoon.ui:updateAll()
end

-- Floating Window Management
local FU = {
    steps = { 1, 0.8, 0.66, 0.5, 0.33, 0.2 },
    pos = {
        left = function(s, w) return { x = s.x, y = s.y, w = w, h = s.h } end,
        right = function(s, w) return { x = s.x + s.w - w, y = s.y, w = w, h = s.h } end,
        up = function(s, _, h) return { x = s.x, y = s.y, w = s.w, h = h } end,
        down = function(s, _, h) return { x = s.x, y = s.y + s.h - h, w = s.w, h = h } end,
        ["up-left"] = function(s, w, h) return { x = s.x, y = s.y, w = w, h = h } end,
        ["up-right"] = function(s, w, h) return { x = s.x + s.w - w, y = s.y, w = w, h = h } end,
        ["down-left"] = function(s, w, h) return { x = s.x, y = s.y + s.h - h, w = w, h = h } end,
        ["down-right"] = function(s, w, h) return { x = s.x + s.w - w, y = s.y + s.h - h, w = w, h = h } end
    }
}

-- Check if window can be freely positioned (tile off OR window is floating)
function Core:isWindowFloating(winId)
    return not self:isTilingEnabled() or self.spoon.tags:isFloating(winId)
end

function Core:floatingWindowPosition(dir)
    local win, id, scr = self:getFloatingTarget()
    if not win then return end

    self.spoon.state.floatingSteps = self.spoon.state.floatingSteps or {}
    self.spoon.state.floatingSteps[id] = self.spoon.state.floatingSteps[id] or { side = nil, ws = 1, hs = 1 }
    local st = self.spoon.state.floatingSteps[id]
    local side = st.side
    if not side then
        side = dir; st.ws, st.hs = 1, 1
    elseif side == dir then
        if dir == "left" or dir == "right" then st.ws = (st.ws % #FU.steps) + 1 else st.hs = (st.hs % #FU.steps) + 1 end
    elseif not side:find("-") then
        if (side == "left" or side == "right") and (dir == "up" or dir == "down") then
            side = dir .. "-" .. side; st.hs = 1
        elseif (side == "up" or side == "down") and (dir == "left" or dir == "right") then
            side = side .. "-" .. dir; st.ws = 1
        else
            side = dir; st.ws, st.hs = 1, 1
        end
    else
        local v, h = side:match("([^-]+)-([^-]+)")
        if dir == "left" or dir == "right" then
            if dir == h then
                st.ws = (st.ws % #FU.steps) + 1
            else
                side = v .. "-" .. dir; st.ws = 1
            end
        else
            if dir == v then
                st.hs = (st.hs % #FU.steps) + 1
            else
                side = dir .. "-" .. h; st.hs = 1
            end
        end
    end
    st.side = side
    local w = scr.w * FU.steps[st.ws]; local h = scr.h * FU.steps[st.hs]
    if side == "left" or side == "right" then h = scr.h elseif side == "up" or side == "down" then w = scr.w end
    pcall(function() win:setFrame(FU.pos[side](scr, w, h)) end)
    self:showAlert(string.format("%s: %d%%×%d%%", side, FU.steps[st.ws] * 100, FU.steps[st.hs] * 100))
end

function Core:floatingWindowFullscreen()
    local win, id, scr = self:getFloatingTarget()
    if not win then return end

    self.spoon.state.floatingSteps = self.spoon.state.floatingSteps or {}
    self.spoon.state.floatingSteps[id] = self.spoon.state.floatingSteps[id] or {}
    local step = (self.spoon.state.floatingSteps[id].fs or 0) % 5 + 1
    self.spoon.state.floatingSteps[id].fs = step
    local steps = { 1, 0.8, 0.6, 0.4, 0.2 }
    local r = steps[step]
    pcall(function()
        win:setFrame({ x = scr.x + scr.w * (1 - r) / 2, y = scr.y + scr.h * (1 - r) / 2, w = scr.w * r, h = scr.h * r })
    end)
    self:showAlert(string.format("%d%%", r * 100))
end

-- dwm killclient: close the focused window
function Core:killClient()
    local win = hs.window.focusedWindow()
    if not win then
        self:showAlert("No focused window"); return
    end
    local ok, closed = pcall(win.close, win)
    if not ok or not closed then self:showAlert("Could not close window") end
end

-- Zoom the focused window to fill the screen, or put it back (not macOS fullscreen: no new Space)
function Core:toggleZoom()
    local win, winId = self:getFocusedWindow()
    local tags = self.spoon.tags
    if not win or not tags:getClient(winId) then
        self:showAlert("No managed window focused"); return
    end

    local client = tags:getClient(winId)
    if client.zoomed then
        tags:setZoomed(winId, false)
        self:showAlert("Unzoomed")
    else
        tags:setZoomed(winId, true)
        self:showAlert("Zoomed")
    end
    self:updateLayout()
    if self.spoon.menubar then self.spoon.menubar:update() end
end

function Core:floatingWindowHalves(pos)
    local win, id, s = self:getFloatingTarget()
    if not win then return end

    local frames = {
        left_half = { x = s.x, y = s.y, w = s.w / 2, h = s.h },
        right_half = { x = s.x + s.w / 2, y = s.y, w = s.w / 2, h = s.h },
        top_half = { x = s.x, y = s.y, w = s.w, h = s.h / 2 },
        bottom_half = { x = s.x, y = s.y + s.h / 2, w = s.w, h = s.h / 2 },
        center = { x = s.x + s.w * 0.15, y = s.y + s.h * 0.15, w = s.w * 0.7, h = s.h * 0.7 },
        maximize = s
    }
    local names = {
        left_half = "Left",
        right_half = "Right",
        top_half = "Top",
        bottom_half = "Bottom",
        center = "Center",
        maximize = "Max"
    }
    if frames[pos] then
        win:setFrame(frames[pos]); self:showAlert(names[pos])
        self.spoon.state.floatingSteps = self.spoon.state.floatingSteps or {}
        self.spoon.state.floatingSteps[id] = {}
    end
end

function Core:floatingWindowNextScreen()
    local win = self:getFloatingTarget()
    if not win then return end

    local cur = win:screen()
    local nextScreen = cur and cur:next()
    if nextScreen and nextScreen ~= cur then
        pcall(function() win:moveToScreen(nextScreen) end)
        self:showAlert(nextScreen:name())
    else
        self:showAlert("One screen")
    end
end

-- Scroll Controls

-- Focus follows the viewport: after scrolling, the most recently used window of the new center column
-- gets focus (otherwise focus would stay on a window that is now in a side column, or off screen)
function Core:focusScrollCenter()
    local layouts, tags = self.spoon.layoutsModule, self.spoon.tags
    local column = layouts.scrollColumns[layouts.scrollViewOffset + 1]
    if not column then return end

    local best
    for _, id in ipairs(column) do
        local client = tags:getClient(id)
        if client and (not best or client.focusSeq > best.focusSeq) then best = client end
    end
    if best then
        tags:noteFocus(best.id)
        pcall(best.win.focus, best.win)
    end
end

function Core:scrollLeft()
    if self.spoon:getCurrentLayoutName() ~= "scroll" then
        self:showAlert("Scroll only"); return
    end
    if self.spoon.layoutsModule and self.spoon.layoutsModule:scrollLeft() then
        self:updateLayout(); self:focusScrollCenter(); self:showAlert("← Scroll")
    else
        self:showAlert("At start")
    end
end

function Core:scrollRight()
    if self.spoon:getCurrentLayoutName() ~= "scroll" then
        self:showAlert("Scroll only"); return
    end
    if self.spoon.layoutsModule and self.spoon.layoutsModule:scrollRight() then
        self:updateLayout(); self:focusScrollCenter(); self:showAlert("Scroll →")
    else
        self:showAlert("At end")
    end
end

-- Unified Tile/Scroll Controls
-- Runs a tile/scroll column operation on the focused window and relayouts on success
function Core:columnOperation(tileFn, scrollFn, successMsg, failMsg)
    local layout = self.spoon:getCurrentLayoutName()
    local win, winId = self:getFocusedWindow()
    if not win then
        self:showAlert("No window"); return
    end

    local layouts = self.spoon.layoutsModule
    local fnName
    if layout == "tile" then
        fnName = tileFn
    elseif layout == "scroll" then
        fnName = scrollFn
    else
        self:showAlert("Tile/Scroll only"); return
    end

    if layouts and layouts[fnName](layouts, winId) then
        self:updateLayout()
        self:showAlert(successMsg)
        self.spoon:saveSettings()
    else
        self:showAlert(failMsg)
    end
end

function Core:createColumn()
    self:columnOperation("tileCreateColumn", "scrollCreateColumn", "New Column", "Cannot create")
end

function Core:moveColumnLeft()
    self:columnOperation("tileMoveLeft", "scrollMoveLeft", "← Column", "Cannot move")
end

function Core:moveColumnRight()
    self:columnOperation("tileMoveRight", "scrollMoveRight", "Column →", "Cannot move")
end

function Core:showLayoutInfo()
    local layout = self.spoon:getCurrentLayoutName()
    local count = #self.spoon.state.windows
    if layout == "tile" and self.spoon.layoutsModule then
        local cols = self.spoon.layoutsModule.tileColumns
        local numCols = cols and #cols or 0
        self:showAlert(string.format("Tiling: %d cols, %d windows", numCols, count))
    else
        self:showAlert(string.format("%s: %d windows", layout:upper(), count))
    end
end

return Core
