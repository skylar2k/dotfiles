-- WM Workspace Manager
-- Manages 9 independent workspaces with hide/show mechanism

local WorkspaceManager = {}
WorkspaceManager.__index = WorkspaceManager

local WORKSPACE_COUNT = 9
WorkspaceManager.WORKSPACE_COUNT = WORKSPACE_COUNT

local function isValidWorkspace(id)
    return type(id) == "number" and id >= 1 and id <= WORKSPACE_COUNT
end

-- hs.geometry objects don't serialize cleanly; keep plain {x,y,w,h} tables
local function plainFrame(f)
    if type(f) ~= "table" then return nil end
    local ok, x, y, w, h = pcall(function() return f.x, f.y, f.w, f.h end)
    if not ok or not x or not y or not w or not h then return nil end
    return { x = x, y = y, w = w, h = h }
end

local function safeWindowId(win)
    local ok, id = pcall(function() return win and win:id() end)
    return ok and id or nil
end

function WorkspaceManager:new(spoon)
    local obj = setmetatable({}, self)
    obj.spoon = spoon
    obj.workspaces = {}        -- workspace_id -> {windows = {winId -> {frame, floating, seq}}, layout = index, focused = winId}
    obj.current = 1
    obj.windowToWorkspace = {} -- winId -> workspace_id
    obj.nextSeq = 1            -- Insertion counter so window order is stable (pairs() order is not)

    for i = 1, WORKSPACE_COUNT do
        obj.workspaces[i] = {
            windows = {},         -- winId -> {frame = {}, floating = bool, seq = number}
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

--- Single place that records a window in a workspace.
--- Returns false if the window is invalid or already tracked.
function WorkspaceManager:registerWindow(win, wsId, frame)
    local winId = safeWindowId(win)
    if not winId or not isValidWorkspace(wsId) then return false end
    if self.windowToWorkspace[winId] then return false end

    if frame == nil then
        local ok, f = pcall(function() return win:frame() end)
        frame = ok and f or nil
    end

    self.workspaces[wsId].windows[winId] = {
        frame = plainFrame(frame),
        floating = self.spoon.state.floatingWindows[winId] or false,
        seq = self.nextSeq,
    }
    self.nextSeq = self.nextSeq + 1
    self.windowToWorkspace[winId] = wsId
    return true
end

--- Add window to current workspace
function WorkspaceManager:addWindow(win)
    return self:registerWindow(win, self.current)
end

--- Add window to a specific workspace (for window rules)
function WorkspaceManager:addWindowToWorkspace(win, targetWsId)
    if not self:registerWindow(win, targetWsId) then return false end

    -- If not current workspace, hide the window
    if targetWsId ~= self.current then
        self:setWindowOffScreen(win, self:getOffScreenPosition())
    end

    return true
end

--- Forget a window that was closed or is otherwise gone
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

--- Keep the per-workspace floating flag in sync with the global floating set
function WorkspaceManager:setFloating(winId, floating)
    if floating then
        self.spoon.state.floatingWindows[winId] = true
    else
        self.spoon.state.floatingWindows[winId] = nil
    end

    local wsId = self.windowToWorkspace[winId]
    local data = wsId and self.workspaces[wsId].windows[winId]
    if data then data.floating = floating and true or false end
end

--- Move window to another workspace
function WorkspaceManager:moveWindowToWorkspace(win, targetWsId, follow)
    if not win or not isValidWorkspace(targetWsId) then return false end

    local winId = safeWindowId(win)
    if not winId then return false end

    local sourceWsId = self.windowToWorkspace[winId]
    if sourceWsId == targetWsId then return false end

    local frameOk, frame = pcall(function() return win:frame() end)
    local wasFloating = self.spoon.state.floatingWindows[winId] or false

    -- Remove from source workspace
    local seq
    if sourceWsId then
        local sourceWs = self.workspaces[sourceWsId]
        local data = sourceWs.windows[winId]
        if data then
            wasFloating = wasFloating or data.floating
            seq = data.seq
            sourceWs.windows[winId] = nil
        end
        if sourceWs.focused == winId then sourceWs.focused = nil end
        -- Window count changed: rebuild that workspace's columns next time
        sourceWs.needsRetile = true
        sourceWs.tileColumns = {}
        sourceWs.scrollColumns = {}
    end

    -- Add to target workspace
    local targetWs = self.workspaces[targetWsId]
    targetWs.windows[winId] = {
        frame = frameOk and plainFrame(frame) or nil,
        floating = wasFloating,
        seq = seq or self.nextSeq,
    }
    if not seq then self.nextSeq = self.nextSeq + 1 end
    self.windowToWorkspace[winId] = targetWsId

    if wasFloating then
        self.spoon.state.floatingWindows[winId] = true
    end

    -- Hide window immediately (moving it off-screen)
    self:hideWindow(win)

    -- Clear saved columns since window count changed
    targetWs.tileColumns = {}
    targetWs.scrollColumns = {}

    if follow then
        self:switchToWorkspace(targetWsId, true) -- forceRetile since we added a window
    else
        -- Mark target workspace as needing retile when we switch to it later
        targetWs.needsRetile = true
        -- Not following: retile the remaining windows of the source workspace
        if self.spoon.layoutsModule then
            self.spoon.layoutsModule.tileColumns = {}
            self.spoon.layoutsModule.scrollColumns = {}
        end
        self.spoon.state.layoutChanged = true
        self.spoon:updateLayout(true)
    end

    return true
end

--- Hide a window (move off-screen instantly)
function WorkspaceManager:hideWindow(win)
    local winId = safeWindowId(win)
    if not winId then return end

    local wsId = self.windowToWorkspace[winId]
    local data = wsId and self.workspaces[wsId].windows[winId]
    if not data then return end

    local ok, frame = pcall(function() return win:frame() end)
    if ok then data.frame = plainFrame(frame) end
    self:setWindowOffScreen(win, self:getOffScreenPosition())
end

--- Drop windows that no longer exist from a workspace. Returns the live windows as {win, data} pairs.
function WorkspaceManager:collectLiveWindows(ws)
    local live = {}
    for winId, data in pairs(ws.windows) do
        local win = hs.window.get(winId)
        if win then
            live[#live + 1] = { win = win, data = data, id = winId }
        else
            ws.windows[winId] = nil
            self.windowToWorkspace[winId] = nil
            if ws.focused == winId then ws.focused = nil end
        end
    end
    table.sort(live, function(a, b) return (a.data.seq or a.id) < (b.data.seq or b.id) end)
    return live
end

--- Switch to a different workspace (optimized for speed)
--- @param targetWsId number The workspace ID to switch to
--- @param forceRetile boolean If true, recalculate layout instead of restoring saved frames
function WorkspaceManager:switchToWorkspace(targetWsId, forceRetile)
    if not isValidWorkspace(targetWsId) then return false end
    if targetWsId == self.current then return false end

    local currentWs = self:getCurrentWorkspace()
    local targetWs = self.workspaces[targetWsId]
    local layoutsModule = self.spoon.layoutsModule
    local offScreen = self:getOffScreenPosition()

    -- Remember the focused window of the workspace we're leaving
    local focusedId = safeWindowId(hs.window.focusedWindow())
    if focusedId and self.windowToWorkspace[focusedId] == self.current then
        currentWs.focused = focusedId
    end

    -- Save current layout columns to workspace
    if layoutsModule then
        currentWs.tileColumns = layoutsModule.tileColumns or {}
        currentWs.scrollColumns = layoutsModule.scrollColumns or {}
        currentWs.scrollViewOffset = layoutsModule.scrollViewOffset or 0
    end

    -- Record frames of the windows we're about to hide
    local toHide = self:collectLiveWindows(currentWs)
    for _, entry in ipairs(toHide) do
        local ok, frame = pcall(function() return entry.win:frame() end)
        if ok and frame then entry.data.frame = plainFrame(frame) end
    end

    local toShow = self:collectLiveWindows(targetWs)

    -- Switch workspace first (before moving windows)
    self.current = targetWsId

    -- Restore layout columns from target workspace
    if layoutsModule then
        layoutsModule.tileColumns = targetWs.tileColumns or {}
        layoutsModule.scrollColumns = targetWs.scrollColumns or {}
        layoutsModule.scrollViewOffset = targetWs.scrollViewOffset or 0
    end

    -- Hide old windows FIRST (they're going away)
    for _, entry in ipairs(toHide) do
        self:setWindowOffScreen(entry.win, offScreen)
    end

    local needsRetile = forceRetile or targetWs.needsRetile
    self.spoon.helpers:log("debug", string.format("switchToWorkspace %d forceRetile=%s needsRetile=%s windows=%d",
        targetWsId, tostring(forceRetile), tostring(targetWs.needsRetile), #toShow))

    if needsRetile then
        -- Window count changed while away: recalculate layout
        targetWs.needsRetile = false
        self.spoon.state.layoutChanged = true
        self.spoon:updateLayout(true)
    else
        -- Fast path: restore saved frames directly
        for _, entry in ipairs(toShow) do
            local f = entry.data.frame
            if f and f.w and f.w > 0 then
                pcall(function() entry.win:setFrame(f) end)
            end
        end
        local windows = {}
        for _, entry in ipairs(toShow) do windows[#windows + 1] = entry.win end
        self.spoon.state.windows = windows
    end

    -- Focus last focused window
    local focusWin = targetWs.focused and hs.window.get(targetWs.focused)
    if not focusWin and toShow[1] then focusWin = toShow[1].win end
    if focusWin then pcall(function() focusWin:focus() end) end

    return true
end

--- Get windows for current workspace (for layout), in stable insertion order
function WorkspaceManager:getWindowsForLayout()
    local ws = self:getCurrentWorkspace()
    local screen = hs.screen.mainScreen()
    local sf = screen and screen:frame()
    local windows = {}

    for _, entry in ipairs(self:collectLiveWindows(ws)) do
        if not entry.data.floating then
            local win = entry.win
            local minOk, isMinimized = pcall(function() return win:isMinimized() end)
            if minOk and not isMinimized then
                -- Skip windows parked off-screen at the bottom-right
                local ok, frame = pcall(function() return win:frame() end)
                if ok and frame and (not sf or (frame.x <= sf.x + sf.w and frame.y <= sf.y + sf.h)) then
                    windows[#windows + 1] = win
                end
            end
        end
    end

    return windows
end

--- Get workspace window count
function WorkspaceManager:getWindowCount(wsId)
    local ws = self.workspaces[wsId or self.current]
    if not ws then return 0 end

    local count = 0
    for _ in pairs(ws.windows) do
        count = count + 1
    end
    return count
end

--- Serialize workspace assignments so they survive a reload (window ids are stable across reloads)
function WorkspaceManager:serialize()
    local layoutsModule = self.spoon.layoutsModule
    local data = { current = self.current, workspaces = {} }

    for i = 1, WORKSPACE_COUNT do
        local ws = self.workspaces[i]
        local windows = {}
        for winId, winData in pairs(ws.windows) do
            windows[tostring(winId)] = {
                frame = plainFrame(winData.frame),
                floating = winData.floating or false,
                seq = winData.seq,
            }
        end

        -- Live column state for the current workspace lives in the layouts module
        local live = (i == self.current) and layoutsModule
        data.workspaces[i] = {
            layout = ws.layout,
            focused = ws.focused,
            windows = windows,
            tileColumns = (live and layoutsModule.tileColumns or ws.tileColumns) or {},
            scrollColumns = (live and layoutsModule.scrollColumns or ws.scrollColumns) or {},
            scrollViewOffset = (live and layoutsModule.scrollViewOffset or ws.scrollViewOffset) or 0,
        }
    end

    return data
end

--- Restore saved workspace assignments. Windows that no longer exist are dropped.
--- Must run before the window filter starts so existing windows aren't re-added to the current workspace.
function WorkspaceManager:restore(data)
    if type(data) ~= "table" or type(data.workspaces) ~= "table" then return false end

    local restored = 0
    for i = 1, WORKSPACE_COUNT do
        local saved, ws = data.workspaces[i], self.workspaces[i]
        if type(saved) == "table" then
            ws.layout = saved.layout or ws.layout
            ws.scrollViewOffset = saved.scrollViewOffset or 0
            ws.tileColumns = saved.tileColumns or {}
            ws.scrollColumns = saved.scrollColumns or {}
            ws.focused = saved.focused

            for idStr, winData in pairs(saved.windows or {}) do
                local winId = tonumber(idStr)
                local win = winId and hs.window.get(winId)
                if win and self.spoon.helpers:isRelevantWindow(win) and not self.windowToWorkspace[winId] then
                    local seq = tonumber(winData.seq) or self.nextSeq
                    ws.windows[winId] = {
                        frame = plainFrame(winData.frame),
                        floating = winData.floating or false,
                        seq = seq,
                    }
                    self.nextSeq = math.max(self.nextSeq, seq + 1)
                    self.windowToWorkspace[winId] = i
                    if winData.floating then self.spoon.state.floatingWindows[winId] = true end
                    restored = restored + 1
                end
            end

            if ws.focused and not ws.windows[ws.focused] then ws.focused = nil end
        end
    end

    local current = tonumber(data.current)
    if isValidWorkspace(current) then self.current = current end

    -- The layouts module holds the live columns of the current workspace
    local layoutsModule, cur = self.spoon.layoutsModule, self:getCurrentWorkspace()
    if layoutsModule then
        layoutsModule.tileColumns = cur.tileColumns or {}
        layoutsModule.scrollColumns = cur.scrollColumns or {}
        layoutsModule.scrollViewOffset = cur.scrollViewOffset or 0
    end

    return restored > 0
end

--- Adopt windows we don't know about into the current workspace (anything restored keeps its workspace)
function WorkspaceManager:syncExistingWindows()
    local screen = hs.screen.mainScreen()
    local sf = screen and screen:frame()

    for _, win in ipairs(hs.window.allWindows()) do
        local winId = safeWindowId(win)
        if winId and not self.windowToWorkspace[winId] and self.spoon.helpers:isRelevantWindow(win) then
            local ok, frame = pcall(function() return win:frame() end)
            frame = ok and frame or nil

            -- A window parked off-screen by a previous session that we can't place: bring it back
            if frame and sf and frame.x >= sf.x + sf.w - 2 and frame.y >= sf.y + sf.h - 2 then
                frame = { x = sf.x + sf.w * 0.2, y = sf.y + sf.h * 0.2, w = sf.w * 0.6, h = sf.h * 0.6 }
                pcall(function() win:setFrame(frame) end)
            end

            self:registerWindow(win, self.current, frame or false)
        end
    end
end

--- Re-scan all windows without losing workspace assignments: drop dead windows, adopt new ones
function WorkspaceManager:rescan()
    for i = 1, WORKSPACE_COUNT do
        self:collectLiveWindows(self.workspaces[i])
    end
    self:syncExistingWindows()
end

return WorkspaceManager
