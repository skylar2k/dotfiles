-- WM API
local API = {}
API.__index = API

function API:new(spoon)
    return setmetatable({ spoon = spoon }, self)
end

function API:cycleLayout()
    local current = self.spoon:getLayoutForCurrentSpace()
    local newIndex = (current % #self.spoon.layouts) + 1
    self.spoon:setLayoutForCurrentSpace(newIndex)
    self.spoon.core:showAlert("Layout: " .. self.spoon.layouts[newIndex]:upper())
    self.spoon.state.layoutChanged = true
    self.spoon:updateLayout()
    -- Update menubar immediately
    if self.spoon.menubar then self.spoon.menubar:update() end
end

function API:chooseLayout()
    local choices = {}
    for i, name in ipairs(self.spoon.layouts) do
        table.insert(choices, {
            text = name:upper(),
            subText = name == self.spoon:getCurrentLayoutName() and "Current" or "",
            index = i
        })
    end

    local spoon = self.spoon
    hs.chooser.new(function(choice)
        if choice then
            spoon:setLayoutForCurrentSpace(choice.index)
            spoon.state.layoutChanged = true
            spoon:updateLayout()
            -- Update menubar immediately
            if spoon.menubar then spoon.menubar:update() end
        end
    end):choices(choices):show()
end

function API:togglePerSpaceLayouts()
    self.spoon.config.usePerSpaceLayouts = not self.spoon.config.usePerSpaceLayouts
    self.spoon.core:showAlert("Per-space layouts: " .. (self.spoon.config.usePerSpaceLayouts and "ON" or "OFF"))
    self.spoon:saveSettings()
end

function API:bindHotkeys(mapping)
    local core, spoon = self.spoon.core, self.spoon

    local def = {
        -- Unified window focus (works in all layouts)
        focus = function() core:focusNextWindow() end,
        focusNext = function() core:focusNextWindow() end,
        focusPrev = function() core:focusPrevWindow() end,

        -- Toggle window floating state
        toggleFloatingWindow = function() core:toggleFloatingWindow() end,

        -- Toggle tiling on/off (replaces floating layout)
        toggleTiling = function() core:toggleTiling() end,

        -- Layout management
        cycleLayout = function() self:cycleLayout() end,
        chooseLayout = function() self:chooseLayout() end,
        togglePerSpaceLayouts = function() self:togglePerSpaceLayouts() end,

        -- Unified resize (tiling: column/row, scroll: scroll)
        resizeLeft = function() core:resizeFocusedWindow("left") end,
        resizeRight = function() core:resizeFocusedWindow("right") end,
        resizeUp = function() core:resizeFocusedWindow("up") end,
        resizeDown = function() core:resizeFocusedWindow("down") end,

        -- Balance/reset layout
        balanceLayout = function() core:balanceLayout() end,
        forceRetile = function() self:forceRetile() end,

        -- Floating window positioning (works when tiling is OFF or window is floating)
        floatingPositionUp = function() core:floatingWindowPosition("up") end,
        floatingPositionDown = function() core:floatingWindowPosition("down") end,
        floatingPositionLeft = function() core:floatingWindowPosition("left") end,
        floatingPositionRight = function() core:floatingWindowPosition("right") end,
        floatingFullscreen = function() core:floatingWindowFullscreen() end,
        floatingNextScreen = function() core:floatingWindowNextScreen() end,
        floatingHalfLeft = function() core:floatingWindowHalves("left_half") end,
        floatingHalfRight = function() core:floatingWindowHalves("right_half") end,
        floatingHalfTop = function() core:floatingWindowHalves("top_half") end,
        floatingHalfBottom = function() core:floatingWindowHalves("bottom_half") end,
        floatingCenter = function() core:floatingWindowHalves("center") end,
        floatingMaximize = function() core:floatingWindowHalves("maximize") end,

        -- Universal fullscreen (works in any layout)
        toggleFullscreen = function() core:toggleFullscreen() end,

        -- Layout info
        showLayoutInfo = function() core:showLayoutInfo() end,
        showWindowInfo = function() core:showWindowInfo() end,

        -- Unified swap (works in all tiled layouts)
        swapNext = function() core:swapWindow("next") end,
        swapPrev = function() core:swapWindow("prev") end,

        -- Tile/Scroll column controls (works in both layouts)
        createColumn = function() core:createColumn() end,
        moveColumnLeft = function() core:moveColumnLeft() end,
        moveColumnRight = function() core:moveColumnRight() end,

        -- Scroll-specific commands
        scrollLeft = function() core:scrollLeft() end,
        scrollRight = function() core:scrollRight() end,
    }

    -- Generate position functions dynamically
    for i = 1, 6 do
        def["moveToPosition" .. i] = function() core:moveToPosition(i) end
    end

    -- Generate workspace functions dynamically (1-9)
    for i = 1, 9 do
        def["focusWorkspace" .. i] = function() self:focusWorkspace(i) end
        def["moveToWorkspace" .. i] = function() self:moveToWorkspace(i, true) end      -- Follow by default
        def["moveToWorkspaceStay" .. i] = function() self:moveToWorkspace(i, false) end -- Stay in current workspace
    end

    hs.spoons.bindHotkeysToSpec(def, mapping)
    return spoon
end

-- Workspace management
function API:focusWorkspace(id, silent)
    local wm = self.spoon.workspaceManager
    if not wm then
        self.spoon.core:showAlert("No workspace manager")
        return
    end

    if wm.current == id then
        local count = wm:getWindowCount(id) or 0
        self.spoon.core:showAlert("Workspace " .. id .. " (" .. count .. " windows)")
        return
    end

    -- Set flag to ignore focus events during workspace switch
    self.spoon.state.switchingWorkspace = true
    -- Focus events caused by the switch itself must not trigger another switch
    local success = wm:switchToWorkspace(id)
    if success then
        local count = wm:getWindowCount() or 0
        if not silent then self.spoon.core:showAlert("Workspace " .. id .. " (" .. count .. " windows)") end
        -- Don't call updateLayout here - switchToWorkspace already restores window frames
        -- Just sync the window list for the new workspace
        local windows = wm:getWindowsForLayout()
        self.spoon.state.windows = windows
        self.spoon.ui:updateAll()
        if self.spoon.menubar then self.spoon.menubar:update() end
        self.spoon:saveSettings()
    end
    -- Clear flag after windows have settled (prevents windowMoved from triggering retile)
    hs.timer.doAfter(0.2, function()
        self.spoon.state.switchingWorkspace = false
    end)
end

function API:moveToWorkspace(id, follow)
    local wm = self.spoon.workspaceManager
    if not wm then
        self.spoon.core:showAlert("No workspace manager")
        return
    end

    local win = hs.window.focusedWindow()
    if not win then
        self.spoon.core:showAlert("No focused window")
        return
    end

    -- Set flag to prevent focus events from switching workspace back
    if follow then
        self.spoon.state.switchingWorkspace = true
    end

    local success = wm:moveWindowToWorkspace(win, id, follow)
    if success then
        if follow then
            self.spoon.core:showAlert("Workspace " .. id)
        else
            self.spoon.core:showAlert("Moved to workspace " .. id)
            -- Only update layout here if NOT following (follow already updates inside moveWindowToWorkspace)
            self.spoon:updateLayout(true)
        end
        if self.spoon.menubar then self.spoon.menubar:update() end
        self.spoon.ui:updateAll()
        self.spoon:saveSettings()
    end

    -- Clear flag after windows have settled
    if follow then
        hs.timer.doAfter(0.2, function()
            self.spoon.state.switchingWorkspace = false
        end)
    end
end

function API:start()
    local spoon = self.spoon
    local wm = spoon.workspaceManager

    -- Starting twice would double every subscription; tear down the previous run first
    if self.started then self:stop() end
    self.started = true
    self.subscriptions = {}

    -- hs.window.filter.default silently drops whole categories of apps before we ever see them.
    -- Use our own filter instead: every visible window of a role we can manage gets through, and
    -- rules decide what happens to each one. Other roles (popups, menus, banners, alerts) are never
    -- managed, so letting them through would only generate events and relayouts.
    local windowFilter = hs.window.filter.new(true):setDefaultFilter({
        visible = true,
        allowRoles = { "AXStandardWindow", "AXDialog", "AXSystemDialog", "AXFloatingWindow" },
    })
    self.windowFilter = windowFilter
    local function subscribe(event, fn)
        windowFilter:subscribe(event, fn)
        table.insert(self.subscriptions, { event = event, fn = fn })
    end

    -- Start menubar
    if spoon.menubar then spoon.menubar:start() end

    local updateLayout = function(source)
        -- Skip during workspace switching or if explicitly ignored
        if spoon.state.switchingWorkspace or spoon.state.ignoreNextUpdate then
            if spoon.config.debug then
                print("[WM] updateLayout skipped (switching=" ..
                    tostring(spoon.state.switchingWorkspace) .. ") source=" .. (source or "unknown"))
            end
            return
        end
        if spoon.config.debug then print("[WM] updateLayout called from " .. (source or "unknown")) end
        hs.timer.doAfter(spoon.config.timing.layoutUpdateDelay, function()
            -- Double-check flags after delay
            if not spoon.state.switchingWorkspace and not spoon.state.ignoreNextUpdate then
                spoon:updateLayout(false)
                if spoon.menubar then spoon.menubar:update() end
            end
        end)
    end

    -- Restore workspace assignments from the last session BEFORE subscribing to the window
    -- filter, otherwise existing windows get re-added to the current workspace
    if wm and spoon.state.pendingWorkspaces then
        wm:restore(spoon.state.pendingWorkspaces)
    end
    spoon.state.pendingWorkspaces = nil

    -- Apply the rules to a window: track it (tiled or floating), move it to a workspace, or ignore it.
    -- Also used to re-check shortly after creation, when title/subrole/buttons often aren't final yet.
    local function processWindow(win, isRecheck)
        local winId = spoon.helpers:getWindowId(win)
        if not winId or not wm then return end

        -- A float/tile choice made by hand always wins over rules
        if isRecheck and wm:isManuallyFloated(winId) then return end

        local result = spoon.rules:classify(win)
        local before = wm.windowToWorkspace[winId] and (spoon.state.floatingWindows[winId] and "float" or "tile") or "ignore"
        if spoon.config.debug and (not isRecheck or before ~= result.manage) then
            -- Only cheap lookups here: describe() would query the accessibility tree for every window
            local appOk, appName = pcall(function() return win:application():name() end)
            local titleOk, title = pcall(function() return win:title() end)
            local roleOk, subrole = pcall(function() return win:subrole() end)
            print(string.format("[WM rules] %s | %q | subrole=%s -> %s (%s)%s",
                appOk and appName or "?", titleOk and title or "?", roleOk and tostring(subrole) or "?",
                result.manage, tostring(result.rule or "no rule"), isRecheck and " [recheck]" or ""))
        end

        local tracked = wm.windowToWorkspace[winId]

        if result.manage == "ignore" then
            if tracked then
                wm:removeWindow(winId)
                spoon.state.floatingWindows[winId] = nil
                updateLayout("windowIgnored")
            end
            return
        end

        local floating = result.manage == "float"
        if not tracked then
            if result.workspace and result.workspace ~= wm.current then
                wm:addWindowToWorkspace(win, result.workspace, floating)
            else
                wm:addWindow(win, floating)
            end
        elseif (spoon.state.floatingWindows[winId] or false) ~= floating then
            wm:setFloating(winId, floating)
        end

        -- Geometry only makes sense for floating windows; tiled ones are placed by the layout
        if floating and not isRecheck then
            local ok, frame = pcall(function() return win:frame() end)
            local screen = hs.screen.mainScreen()
            if ok and frame and screen then
                local new = { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
                if result.dimensions then new.w, new.h = result.dimensions[1], result.dimensions[2] end
                if result.position then new.x, new.y = result.position[1], result.position[2] end
                if result.center then
                    local sf = screen:frame()
                    new.x, new.y = sf.x + (sf.w - new.w) / 2, sf.y + (sf.h - new.h) / 2
                end
                if result.dimensions or result.position or result.center then
                    pcall(function() win:setFrame(new) end)
                end
            end
        end

        updateLayout(isRecheck and "windowRecheck" or "windowCreated")
    end

    subscribe(hs.window.filter.windowCreated, function(win)
        if not win then return end
        processWindow(win, false)

        -- Titles, subroles and buttons are often not final at creation: look again once things settle
        local winId = spoon.helpers:getWindowId(win)
        hs.timer.doAfter(spoon.config.timing.ruleRecheckDelay or 0.4, function()
            local live = winId and hs.window.get(winId)
            if live then processWindow(live, true) end
        end)
    end)

    -- Window destroyed - remove from workspace
    subscribe(hs.window.filter.windowDestroyed, function(win)
        if win then
            local winId = win:id()
            if winId and wm then wm:removeWindow(winId) end
            updateLayout("windowDestroyed")
        end
    end)

    -- Window minimized/unminimized
    subscribe(hs.window.filter.windowMinimized, function(win)
        -- Set flag to prevent workspace switch when minimizing causes focus change
        spoon.state.justMinimized = true
        hs.timer.doAfter(0.15, function()
            spoon.state.justMinimized = false
        end)
        updateLayout("windowMinimized")
    end)

    subscribe(hs.window.filter.windowUnminimized, function() updateLayout("windowUnminimized") end)
    subscribe(hs.window.filter.windowsChanged, function() updateLayout("windowsChanged") end)

    local lastFocusedWinId = nil
    local lastFocusTime = 0
    subscribe(hs.window.filter.windowFocused, function(win)
        if not win then return end
        local winId = spoon.helpers:getWindowId(win)
        if not winId then return end

        -- The filter reports the already-focused window when it starts: that is not a user action
        if not spoon.state.ready then return end

        -- Skip focus handling during workspace switching or right after minimize
        if spoon.state.switchingWorkspace or spoon.state.justMinimized or spoon.state.rotatingStack then return end

        -- Focusing a window that lives in another workspace (Dock click, Cmd+Tab) switches to it.
        -- This must come before the de-duplication below, or re-focusing the same window never switches.
        local targetWs = wm and wm.windowToWorkspace[winId]
        if targetWs and targetWs ~= wm.current then
            wm.workspaces[targetWs].focused = winId -- Land on the window the user asked for
            self:focusWorkspace(targetWs, true) -- Silent: this isn't a keypress, so no alert
            lastFocusedWinId = winId
            return
        end

        if targetWs == wm.current then wm:getCurrentWorkspace().focused = winId end

        -- Prevent focus loop: skip if same window focused again
        if winId == lastFocusedWinId then return end

        -- Debounce rapid focus changes (prevent loops)
        local now = hs.timer.secondsSinceEpoch()
        if now - lastFocusTime < 0.1 then return end
        lastFocusTime = now
        lastFocusedWinId = winId

        -- For Scroll: scroll to show the focused window's column
        local layoutsModule = spoon.layoutsModule
        if layoutsModule and spoon:getCurrentLayoutName() == "scroll" then
            local colIdx = layoutsModule:scrollFindWindow(winId)
            -- Only update if offset actually changed to prevent focus loops
            if colIdx and layoutsModule.scrollViewOffset ~= colIdx - 1 then
                layoutsModule.scrollViewOffset = colIdx - 1
                spoon:updateLayout(true)
            end
        end

        pcall(function() win:raise() end)
        spoon.ui:updateAll()
    end)

    subscribe(hs.window.filter.windowMoved, function(win)
        if win then
            local winId = win:id()
            -- Skip during workspace switching to prevent re-tiling restored windows
            if spoon.state.switchingWorkspace then return end
            if winId and not (spoon.state.floatingWindows[winId] or spoon.state.ignoreNextUpdate) then
                hs.timer.doAfter(spoon.config.timing.layoutUpdateDelay, function()
                    -- Double-check we're not still switching
                    if not spoon.state.switchingWorkspace then
                        spoon:updateLayout(true)
                    end
                end)
            end
        end
    end)

    -- Mouse drag swap using eventtap
    local dragWin = nil
    local dragStartFrame = nil
    local originalFrames = {}
    local DRAG_MOVE_THRESHOLD = 20 -- px the window itself must move to count as a window drag

    spoon.dragTap = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDragged }, function(e)
        if not dragWin then
            dragWin = hs.window.focusedWindow()
            dragStartFrame = dragWin and dragWin:frame() or nil
            if dragWin and spoon.state.windows then
                -- Store original frames of all windows
                originalFrames = {}
                for i, w in ipairs(spoon.state.windows) do
                    originalFrames[w:id()] = w:frame()
                end
            end
        end
        return false
    end)

    spoon.dragEndTap = hs.eventtap.new({ hs.eventtap.event.types.leftMouseUp }, function(e)
        -- Only treat as a window drag if the window itself moved. Drags inside an
        -- app (text selection, scrollbars, sliders) must never trigger a swap.
        local windowMoved = false
        if dragWin and dragStartFrame then
            local ok, cur = pcall(function() return dragWin:frame() end)
            if ok and cur then
                windowMoved = math.abs(cur.x - dragStartFrame.x) > DRAG_MOVE_THRESHOLD
                    or math.abs(cur.y - dragStartFrame.y) > DRAG_MOVE_THRESHOLD
            end
        end

        if windowMoved and dragWin and spoon.state.windows then
            local winId = dragWin:id()
            if winId and not spoon.state.floatingWindows[winId] then
                local mousePos = hs.mouse.absolutePosition()

                -- Find window under mouse position (using original frames)
                for i, otherWin in ipairs(spoon.state.windows) do
                    if otherWin:id() ~= winId then
                        local origFrame = originalFrames[otherWin:id()]
                        if origFrame and
                            mousePos.x >= origFrame.x and mousePos.x <= origFrame.x + origFrame.w and
                            mousePos.y >= origFrame.y and mousePos.y <= origFrame.y + origFrame.h then
                            -- Found target - swap
                            local srcIdx
                            for j, w in ipairs(spoon.state.windows) do
                                if w:id() == winId then
                                    srcIdx = j; break
                                end
                            end
                            if srcIdx and srcIdx ~= i then
                                spoon.state.ignoreNextUpdate = true
                                spoon.state.windows[srcIdx], spoon.state.windows[i] =
                                    spoon.state.windows[i], spoon.state.windows[srcIdx]

                                -- For Scroll/Tile, swap in column structures
                                local layout = spoon:getCurrentLayoutName()
                                if spoon.layoutsModule then
                                    if layout == "scroll" then
                                        local cols = spoon.layoutsModule.scrollColumns
                                        if cols and srcIdx <= #cols and i <= #cols then
                                            cols[srcIdx], cols[i] = cols[i], cols[srcIdx]
                                        end
                                    elseif layout == "tile" then
                                        -- Swap windows in tileColumns structure
                                        local cols = spoon.layoutsModule.tileColumns
                                        if cols then
                                            -- Find which columns contain these windows
                                            local srcWinId, targetWinId = winId, otherWin:id()
                                            local srcColIdx, srcRowIdx, targetColIdx, targetRowIdx

                                            for colIdx, col in ipairs(cols) do
                                                for rowIdx, wId in ipairs(col.windows) do
                                                    if wId == srcWinId then
                                                        srcColIdx, srcRowIdx = colIdx, rowIdx
                                                    elseif wId == targetWinId then
                                                        targetColIdx, targetRowIdx = colIdx, rowIdx
                                                    end
                                                end
                                            end

                                            -- Swap in the column structure
                                            if srcColIdx and targetColIdx then
                                                cols[srcColIdx].windows[srcRowIdx] = targetWinId
                                                cols[targetColIdx].windows[targetRowIdx] = srcWinId
                                            end
                                        end
                                    end
                                end

                                spoon.core:showAlert("Swapped")
                                hs.timer.doAfter(0.01, function()
                                    spoon:updateLayout(true)
                                    spoon.state.ignoreNextUpdate = false
                                end)
                            end
                            break
                        end
                    end
                end
            end
        end
        dragWin = nil
        dragStartFrame = nil
        originalFrames = {}
        return false
    end)

    spoon.dragTap:start()
    spoon.dragEndTap:start()

    -- Space change watcher
    self.spaceWatcher = hs.spaces.watcher.new(function()
        hs.timer.doAfter(spoon.config.timing.spaceChangeDelay, function()
            spoon.state.layoutChanged = true
            spoon:updateLayout()
        end)
    end):start()

    -- Initial setup
    hs.timer.doAfter(spoon.config.timing.initialSetupDelay, function()
        -- Sync existing windows to workspace 1
        if wm then wm:syncExistingWindows() end

        spoon.state.ready = true -- From here on, settings may be written and focus changes are followed
        spoon.state.layoutChanged = true
        spoon:updateLayout()
        if spoon.menubar then spoon.menubar:update() end

        -- After a reload the focused window can be one parked in another workspace (it kept key status
        -- while hidden): hand focus to the workspace we are actually showing
        local focusedId = spoon.helpers:getWindowId(hs.window.focusedWindow())
        local focusedWs = focusedId and wm.windowToWorkspace[focusedId]
        if focusedWs and focusedWs ~= wm.current then wm:focusCurrentWorkspace() end

        spoon.core:showAlert("WindowManager+ Ready")
    end)

    return spoon
end

--- Append a window rule (see rules.lua for the format)
function API:addRule(rule)
    local rules = self.spoon.config.rules
    rules[#rules + 1] = rule
    self.spoon.rules:invalidate()
    return self.spoon
end

-- Validate and sanitize configuration
function API:validateConfig(config)
    local errors = {}
    local warnings = {}

    -- Validate and fix gap
    if config.gap ~= nil then
        if type(config.gap) ~= "number" or config.gap < 0 then
            table.insert(warnings, "gap must be a non-negative number, using default 8")
            config.gap = 8
        end
    end

    -- Validate and fix timing
    if config.timing then
        local timing = config.timing
        local timingDefaults = {
            layoutUpdateDelay = 0.08,
            spaceChangeDelay = 0.12,
            initialSetupDelay = 0.15,
            windowLockDuration = 0.4,
            ruleRecheckDelay = 0.4
        }
        for field, defaultVal in pairs(timingDefaults) do
            if timing[field] ~= nil and (type(timing[field]) ~= "number" or timing[field] < 0) then
                table.insert(warnings, "timing." .. field .. " invalid, using default " .. defaultVal)
                timing[field] = defaultVal
            end
        end
    end

    -- Validate rules (individual rules are checked when compiled)
    for _, key in ipairs({ "rules", "defaultRules" }) do
        if config[key] ~= nil and type(config[key]) ~= "table" then
            table.insert(warnings, key .. " must be a list of rule tables, ignoring")
            config[key] = nil
        end
    end

    -- Validate modeColors
    if config.modeColors then
        for mode, color in pairs(config.modeColors) do
            if type(color) ~= "string" and type(color) ~= "table" then
                table.insert(errors, "modeColors." .. mode .. " must be a hex string or color table")
            end
        end
    end

    -- Report warnings
    for _, warn in ipairs(warnings) do
        print("[WM Config Warning] " .. warn)
    end

    -- Report errors
    if #errors > 0 then
        for _, err in ipairs(errors) do
            print("[WM Config Error] " .. err)
        end
        hs.alert.show("WindowManagerPlus: " .. #errors .. " config error(s) - check console")
        return false
    end

    return true
end

function API:configure(config)
    -- Validate config first
    self:validateConfig(config)

    for k, v in pairs(config) do
        self.spoon.config[k] = v
    end
    self.spoon:processColors()
    self.spoon.rules:invalidate() -- Rebuild (and report problems in) the rule list
    return self.spoon
end

-- Force retile: rebuild every column structure and re-scan windows. Workspace assignments are kept.
function API:forceRetile()
    local spoon = self.spoon
    local wm = spoon.workspaceManager

    spoon.state.windows = {}

    if wm then
        wm:rescan() -- Drop dead windows, adopt unknown ones into the current workspace
        for i = 1, wm.WORKSPACE_COUNT do
            local ws = wm.workspaces[i]
            ws.tileColumns, ws.scrollColumns, ws.scrollViewOffset = {}, {}, 0
        end
    end
    if spoon.layoutsModule then
        spoon.layoutsModule.tileColumns, spoon.layoutsModule.scrollColumns = {}, {}
        spoon.layoutsModule.scrollViewOffset = 0
    end

    spoon.state.layoutChanged = true
    spoon:updateLayout(false)
    if spoon.menubar then spoon.menubar:update() end
    spoon.core:showAlert("Retiled")

    return spoon
end

-- Stop everything start() set up. Safe to call more than once.
function API:stop()
    local spoon = self.spoon

    self.subscriptions = {}

    if self.windowFilter then
        pcall(function() self.windowFilter:unsubscribeAll() end)
        pcall(function() self.windowFilter:delete() end)
        self.windowFilter = nil
    end

    for _, name in ipairs({ "dragTap", "dragEndTap" }) do
        if spoon[name] then
            spoon[name]:stop(); spoon[name] = nil
        end
    end
    if self.spaceWatcher then
        self.spaceWatcher:stop(); self.spaceWatcher = nil
    end

    if spoon.menubar then spoon.menubar:stop() end
    if spoon.ui then spoon.ui:cleanup() end

    self.started = false
    return spoon
end

return API
