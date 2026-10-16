-- LaWM Workspace Manager
-- Manages 9 independent workspaces with hide/show mechanism

local WorkspaceManager = {}
WorkspaceManager.__index = WorkspaceManager

function WorkspaceManager:new(spoon)
    local obj = setmetatable({}, self)
    obj.spoon = spoon
    obj.workspaces = {}        -- workspace_id -> {windows = {winId -> frame}, layout = index, focused = winId}
    obj.current = 1
    obj.windowToWorkspace = {} -- winId -> workspace_id

    -- Initialize 9 workspaces
    for i = 1, 9 do
        obj.workspaces[i] = {
            windows = {},         -- winId -> {frame = {}, floating = bool}
            layout = 1,           -- layout index (tile, scroll, stack)
            focused = nil,        -- last focused window id
            splitRatios = {},     -- split ratios for this workspace
            tileColumns = {},     -- tiling layout column structure
            scrollColumns = {},   -- scroll layout column structure
            scrollViewOffset = 0, -- scroll view offset
        }
    end

    return obj
end

--- Get off-screen position (bottom-right corner, 1px visible like AeroSpace)
function WorkspaceManager:getOffScreenPosition()
    local screen = hs.screen.mainScreen()
    if not screen then return { x = 10000, y = 10000 } end
    local frame = screen:frame()
    return {
        x = frame.x + frame.w - 1, -- Only 1px visible from right edge
        y = frame.y + frame.h - 1  -- Only 1px visible from bottom edge
    }
end

--- Hide window by moving off-screen (fast version using setTopLeft)
function WorkspaceManager:setWindowOffScreen(win, pos)
    if not win then return end
    pcall(function() win:setTopLeft(pos) end)
end

--- Get current workspace
function WorkspaceManager:getCurrentWorkspace()
    return self.workspaces[self.current]
end

--- Add window to current workspace
function WorkspaceManager:addWindow(win)
    if not win then return false end

    local winId = win:id()
    if not winId then return false end

    -- If window already tracked, skip
    if self.windowToWorkspace[winId] then
        return false
    end

    local ws = self:getCurrentWorkspace()
    local ok, frame = pcall(function() return win:frame() end)

    ws.windows[winId] = {
        frame = ok and frame or nil,
        floating = self.spoon.state.floatingWindows[winId] or false
    }
    self.windowToWorkspace[winId] = self.current

    return true
end

--- Add window to a specific workspace (for window rules)
function WorkspaceManager:addWindowToWorkspace(win, targetWsId)
    if not win then return false end
    if targetWsId < 1 or targetWsId > 9 then return false end

    local winId = win:id()
    if not winId then return false end

    -- If window already tracked, skip
    if self.windowToWorkspace[winId] then
        return false
    end

    local ws = self.workspaces[targetWsId]
    local ok, frame = pcall(function() return win:frame() end)

    ws.windows[winId] = {
        frame = ok and frame or nil,
        floating = self.spoon.state.floatingWindows[winId] or false
    }
    self.windowToWorkspace[winId] = targetWsId

    -- If not current workspace, hide the window
    if targetWsId ~= self.current then
        local offScreen = self:getOffScreenPosition()
        self:setWindowOffScreen(win, offScreen)
    end

    return true
end

--- Remove window from its workspace
function WorkspaceManager:removeWindow(winId)
    local wsId = self.windowToWorkspace[winId]
    if not wsId then return false end

    local ws = self.workspaces[wsId]
    if ws then
        ws.windows[winId] = nil
        if ws.focused == winId then
            ws.focused = nil
        end
    end

    self.windowToWorkspace[winId] = nil
    return true
end

--- Move window to another workspace
function WorkspaceManager:moveWindowToWorkspace(win, targetWsId, follow)
    if not win then return false end
    if targetWsId < 1 or targetWsId > 9 then return false end

    local ok, winId = pcall(function() return win:id() end)
    if not ok or not winId then return false end

    local sourceWsId = self.windowToWorkspace[winId]
    if sourceWsId == targetWsId then return false end

    -- Get current frame before moving
    local frameOk, frame = pcall(function() return win:frame() end)
    local wasFloating = self.spoon.state.floatingWindows[winId] or false

    -- Remove from source workspace
    if sourceWsId then
        local sourceWs = self.workspaces[sourceWsId]
        if sourceWs and sourceWs.windows[winId] then
            wasFloating = wasFloating or sourceWs.windows[winId].floating
            sourceWs.windows[winId] = nil
            if sourceWs.focused == winId then
                sourceWs.focused = nil
            end
            -- Mark source as needing retile (window count changed)
            sourceWs.needsRetile = true
            sourceWs.tileColumns = {}
        end
    end

    -- Add to target workspace
    local targetWs = self.workspaces[targetWsId]
    targetWs.windows[winId] = {
        frame = frameOk and frame or nil,
        floating = wasFloating
    }
    self.windowToWorkspace[winId] = targetWsId

    -- Sync floating state
    if wasFloating then
        self.spoon.state.floatingWindows[winId] = true
    end

    -- Hide window immediately (moving it off-screen)
    self:hideWindow(win)

    -- Clear saved columns since window count changed
    targetWs.tileColumns = {}

    -- Follow to target workspace if requested
    if follow then
        self:switchToWorkspace(targetWsId, true) -- forceRetile since we added a window
    else
        -- Mark target workspace as needing retile when we switch to it later
        targetWs.needsRetile = true
        -- Not following: update source workspace layout to retile remaining windows
        if self.spoon.layoutsModule then
            self.spoon.layoutsModule.tileColumns = {}
        end
        self.spoon.state.layoutChanged = true
        self.spoon:updateLayout(true)
    end

    return true
end

--- Hide a window (move off-screen instantly)
function WorkspaceManager:hideWindow(win)
    if not win then return end

    local winId = win:id()
    if not winId then return end

    local wsId = self.windowToWorkspace[winId]
    if wsId then
        local ws = self.workspaces[wsId]
        if ws and ws.windows[winId] then
            local frame = win:frame()
            ws.windows[winId].frame = { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
            -- Move off-screen (bottom-right, like AeroSpace)
            local offScreen = self:getOffScreenPosition()
            self:setWindowOffScreen(win, offScreen)
        end
    end
end

--- Switch to a different workspace (optimized for speed)
--- @param targetWsId number The workspace ID to switch to
--- @param forceRetile boolean If true, recalculate layout instead of restoring saved frames
function WorkspaceManager:switchToWorkspace(targetWsId, forceRetile)
    if targetWsId < 1 or targetWsId > 9 then return false end
    if targetWsId == self.current then return false end

    local currentWs = self:getCurrentWorkspace()
    local targetWs = self.workspaces[targetWsId]
    local offScreen = self:getOffScreenPosition()

    -- Save focused window
    local focusedWin = hs.window.focusedWindow()
    if focusedWin then
        local ok, focusedId = pcall(function() return focusedWin:id() end)
        if ok and focusedId and self.windowToWorkspace[focusedId] == self.current then
            currentWs.focused = focusedId
        end
    end

    -- Save current layout columns to workspace
    if self.spoon.layoutsModule then
        currentWs.tileColumns = self.spoon.layoutsModule.tileColumns or {}
        currentWs.scrollColumns = self.spoon.layoutsModule.scrollColumns or {}
        currentWs.scrollViewOffset = self.spoon.layoutsModule.scrollViewOffset or 0
    end

    -- Batch hide: collect all windows first, then move them off-screen
    local windowsToHide = {}
    local deadWindowIds = {}
    for winId, winData in pairs(currentWs.windows) do
        local win = hs.window.get(winId)
        if win then
            local ok, frame = pcall(function() return win:frame() end)
            if ok and frame then
                winData.frame = { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
                windowsToHide[#windowsToHide + 1] = win
            end
        else
            -- Window no longer exists, mark for cleanup
            table.insert(deadWindowIds, winId)
        end
    end

    -- Clean up dead windows from source workspace
    for _, winId in ipairs(deadWindowIds) do
        currentWs.windows[winId] = nil
        self.windowToWorkspace[winId] = nil
        if currentWs.focused == winId then
            currentWs.focused = nil
        end
    end

    -- Batch show: collect windows to restore
    local windowsToShow = {}
    for winId, winData in pairs(targetWs.windows) do
        local win = hs.window.get(winId)
        if win then
            windowsToShow[#windowsToShow + 1] = { win = win, frame = winData.frame }
        else
            targetWs.windows[winId] = nil
            self.windowToWorkspace[winId] = nil
            if targetWs.focused == winId then
                targetWs.focused = nil
            end
        end
    end

    -- Switch workspace first (before moving windows)
    self.current = targetWsId

    -- Restore layout columns from target workspace
    if self.spoon.layoutsModule then
        self.spoon.layoutsModule.tileColumns = targetWs.tileColumns or {}
        self.spoon.layoutsModule.scrollColumns = targetWs.scrollColumns or {}
        self.spoon.layoutsModule.scrollViewOffset = targetWs.scrollViewOffset or 0
    end

    -- Hide old windows FIRST (they're going away)
    for _, win in ipairs(windowsToHide) do
        self:setWindowOffScreen(win, offScreen)
    end

    -- Check if workspace needs retile (window was added/removed while away)
    local needsRetile = forceRetile or targetWs.needsRetile

    if self.spoon.helpers and self.spoon.config.debug then
        self.spoon.helpers:log("debug", "switchToWorkspace " ..
            targetWsId ..
            " forceRetile=" ..
            tostring(forceRetile) .. " wsNeedsRetile=" .. tostring(targetWs.needsRetile) .. " windows=" .. #
            windowsToShow)
    end

    if needsRetile then
        -- Recalculate layout (window count changed)
        targetWs.needsRetile = false
        self.spoon.state.layoutChanged = true
        self.spoon:updateLayout(true)
        if self.spoon.helpers and self.spoon.config.debug then
            self.spoon.helpers:log("debug", "Did full retile for ws " .. targetWsId)
        end
    else
        -- Fast path: restore saved frames directly
        if self.spoon.helpers and self.spoon.config.debug then
            self.spoon.helpers:log("debug", "Fast path - restoring " .. #windowsToShow .. " windows")
        end
        for _, data in ipairs(windowsToShow) do
            if data.frame and data.frame.w and data.frame.w > 0 then
                pcall(function() data.win:setFrame(data.frame) end)
            end
        end
        -- Sync window list
        self.spoon.state.windows = {}
        for _, data in ipairs(windowsToShow) do
            table.insert(self.spoon.state.windows, data.win)
        end
    end

    -- Focus last focused window
    if targetWs.focused then
        local focusWin = hs.window.get(targetWs.focused)
        if focusWin then
            pcall(function() focusWin:focus() end)
        end
    elseif #windowsToShow > 0 then
        pcall(function() windowsToShow[1].win:focus() end)
    end

    return true
end

--- Get windows for current workspace (for layout)
function WorkspaceManager:getWindowsForLayout()
    local ws = self:getCurrentWorkspace()
    local windows = {}
    local screen = hs.screen.mainScreen():frame()

    for winId, winData in pairs(ws.windows) do
        if not winData.floating then
            local win = hs.window.get(winId)
            if win then
                -- Skip minimized windows
                local isMinimized = pcall(function() return win:isMinimized() end) and win:isMinimized()
                if isMinimized then
                    -- Skip minimized windows from layout
                else
                    -- Check window is visible (not off-screen at bottom-right)
                    local ok, frame = pcall(function() return win:frame() end)
                    if ok and frame and frame.x <= screen.x + screen.w and frame.y <= screen.y + screen.h then
                        table.insert(windows, win)
                    end
                end
            else
                -- Window no longer exists
                ws.windows[winId] = nil
                self.windowToWorkspace[winId] = nil
            end
        end
    end

    return windows
end

--- Get workspace window count
function WorkspaceManager:getWindowCount(wsId)
    wsId = wsId or self.current
    local ws = self.workspaces[wsId]
    if not ws then return 0 end

    local count = 0
    for _ in pairs(ws.windows) do
        count = count + 1
    end
    return count
end

--- Sync existing windows to workspace 1 on startup
function WorkspaceManager:syncExistingWindows()
    local allWindows = hs.window.allWindows()

    local addedCount = 0
    for _, win in ipairs(allWindows) do
        local isRelevant = self.spoon.helpers:isRelevantWindow(win)
        local winId = win:id()
        local title = win:title() or "untitled"

        if isRelevant then
            if winId and not self.windowToWorkspace[winId] then
                -- Add to workspace 1
                local ws = self.workspaces[1]
                local ok, frame = pcall(function() return win:frame() end)
                ws.windows[winId] = {
                    frame = ok and frame or nil,
                    floating = self.spoon.state.floatingWindows[winId] or false
                }
                self.windowToWorkspace[winId] = 1
                addedCount = addedCount + 1
            end
        end
    end
end

return WorkspaceManager
