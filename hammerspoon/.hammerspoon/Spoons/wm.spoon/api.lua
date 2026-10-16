-- WM API
local API = {}
API.__index = API

function API:new(spoon)
    return setmetatable({ spoon = spoon }, self)
end

--------------------------------------------------------------------------------
-- Layout commands
--------------------------------------------------------------------------------

function API:cycleLayout()
    local spoon = self.spoon
    local newIndex = (spoon:getLayoutIndex() % #spoon.layouts) + 1
    spoon:setLayoutIndex(newIndex)
    spoon.core:showAlert("Layout: " .. spoon.layouts[newIndex]:upper())
    spoon:updateLayout()
    if spoon.menubar then spoon.menubar:update() end
end

function API:chooseLayout()
    local spoon = self.spoon
    local choices = {}
    for i, name in ipairs(spoon.layouts) do
        table.insert(choices, {
            text = name:upper(),
            subText = name == spoon:getCurrentLayoutName() and "Current" or "",
            index = i
        })
    end

    hs.chooser.new(function(choice)
        if choice then
            spoon:setLayoutIndex(choice.index)
            spoon:updateLayout()
            if spoon.menubar then spoon.menubar:update() end
        end
    end):choices(choices):show()
end

--------------------------------------------------------------------------------
-- Hotkeys
--------------------------------------------------------------------------------

function API:bindHotkeys(mapping)
    local core, spoon = self.spoon.core, self.spoon
    local tags = spoon.tags

    local def = {
        -- Unified window focus (works in all layouts)
        focus = function() core:focusNextWindow() end,
        focusNext = function() core:focusNextWindow() end,
        focusPrev = function() core:focusPrevWindow() end,

        -- Toggle window floating state
        toggleFloatingWindow = function() core:toggleFloatingWindow() end,

        -- Toggle tiling on/off (replaces floating layout)
        toggleTiling = function() core:toggleTiling() end,

        -- Layout management (layouts are per tag, like dwm's pertag)
        cycleLayout = function() self:cycleLayout() end,
        chooseLayout = function() self:chooseLayout() end,

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

        -- Zoom: the focused window temporarily fills the screen
        toggleZoom = function() core:toggleZoom() end,

        -- dwm killclient
        killClient = function() core:killClient() end,

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

        -- Tags, as in dwm
        viewAllTags = function() self:viewTags(tags.ALL) end,
        viewPreviousTags = function() self:viewTags(0) end,
        tagWindowAll = function() self:tagWindow(tags.ALL) end,
    }

    for i = 1, 6 do
        def["moveToPosition" .. i] = function() core:moveToPosition(i) end
    end

    -- dwm spawn: one spawn_<name> action per entry of config.commands
    for name in pairs(spoon.config.commands) do
        def["spawn_" .. name] = function() self:spawn(name) end
    end

    for i = 1, tags.COUNT do
        local bit = tags.bit(i)
        def["viewTag" .. i] = function() self:viewTags(bit) end                    -- dwm view
        def["toggleViewTag" .. i] = function() self:toggleViewTags(bit) end        -- dwm toggleview
        def["tagWindow" .. i] = function() self:tagWindow(bit) end                 -- dwm tag
        def["toggleWindowTag" .. i] = function() self:toggleWindowTag(bit) end     -- dwm toggletag
        def["tagWindowAndView" .. i] = function() self:tagWindow(bit, true) end    -- tag, then follow
    end

    hs.spoons.bindHotkeysToSpec(def, mapping)
    return spoon
end

--------------------------------------------------------------------------------
-- Spawn
--------------------------------------------------------------------------------

--- dwm spawn: run a program. `command` is the name of an entry in config.commands, a shell command
--- string, or { program, arg, ... }. Shell strings run through a login shell so your PATH applies.
function API:spawn(command)
    local spoon = self.spoon
    local spec = spoon.config.commands[command] or command

    local program, args
    if type(spec) == "string" then
        program, args = "/bin/zsh", { "-lc", spec }
    elseif type(spec) == "table" and type(spec[1]) == "string" then
        program, args = spec[1], { table.unpack(spec, 2) }
    else
        spoon.core:showAlert("Nothing to spawn")
        return false
    end

    self.tasks = self.tasks or {}
    local task
    task = hs.task.new(program, function(exitCode, _, stderr)
        self.tasks[task] = nil
        if exitCode ~= 0 then
            print(string.format("[WM spawn] %s exited with %s: %s", tostring(command), tostring(exitCode), tostring(stderr)))
        end
    end, args)
    if not task or not task:start() then
        spoon.core:showAlert("Could not start " .. tostring(command))
        return false
    end
    self.tasks[task] = true -- Keep a reference while it runs
    return true
end

--------------------------------------------------------------------------------
-- Tag commands
--------------------------------------------------------------------------------

-- "Tag 2 (3 windows)" / "Tags 1+2 (5 windows)"
function API:describeView()
    local tags = self.spoon.tags
    local list = tags.list(tags:viewMask())
    local label
    if #list == tags.COUNT then
        label = "All tags"
    else
        label = (#list == 1 and "Tag " or "Tags ") .. table.concat(list, "+")
    end
    return string.format("%s (%d windows)", label, tags:count())
end

--- Re-apply the view after it (or a window's tags) changed: park what left, show what arrived,
--- retile, and hand focus to a window in view
function API:refreshView()
    local spoon = self.spoon
    local tags = spoon.tags

    -- Moves and focus changes caused by this are ours, not the user's
    spoon.state.viewChanging = true

    tags:applyVisibility()
    spoon:updateLayout()
    tags:focusCurrent()
    spoon.ui:updateAll()
    if spoon.menubar then spoon.menubar:update() end

    hs.timer.doAfter(0.2, function()
        spoon.state.viewChanging = false
        -- A window event that arrived mid-change asked for a layout: do it now
        if spoon.state.layoutDeferred then
            spoon.state.layoutDeferred = false
            spoon:updateLayout()
            if spoon.menubar then spoon.menubar:update() end
        end
    end)
end

--- dwm view: show exactly these tags (0 = previous view). `silent` skips the alert.
function API:viewTags(mask, silent)
    local spoon = self.spoon
    if not spoon.tags:view(mask) then
        if not silent then spoon.core:showAlert(self:describeView()) end
        return false
    end

    spoon.helpers:log("debug", "view -> " .. self:describeView())
    self:refreshView()
    if not silent then spoon.core:showAlert(self:describeView()) end
    return true
end

--- dwm toggleview: add or remove tags from the view
function API:toggleViewTags(mask)
    local spoon = self.spoon
    if not spoon.tags:toggleView(mask) then return false end

    self:refreshView()
    spoon.core:showAlert(self:describeView())
    return true
end

--- dwm tag: put the focused window on these tags. With `follow` the view moves along (tag, then view).
function API:tagWindow(mask, follow)
    local spoon = self.spoon
    local win, winId = spoon.core:getFocusedWindow()
    if not win or not spoon.tags:getClient(winId) then
        spoon.core:showAlert("No managed window focused")
        return false
    end

    spoon.tags:setWindowTags(winId, mask)
    if follow then spoon.tags:view(mask) end
    self:refreshView()
    spoon.core:showAlert(follow and self:describeView() or ("Window -> " .. self:describeTags(winId)))
    return true
end

--- dwm toggletag: add or remove tags on the focused window
function API:toggleWindowTag(mask)
    local spoon = self.spoon
    local win, winId = spoon.core:getFocusedWindow()
    if not win or not spoon.tags:getClient(winId) then
        spoon.core:showAlert("No managed window focused")
        return false
    end

    if not spoon.tags:toggleWindowTag(winId, mask) then return false end
    self:refreshView()
    spoon.core:showAlert("Window -> " .. self:describeTags(winId))
    return true
end

function API:describeTags(winId)
    local tags = self.spoon.tags
    local c = tags:getClient(winId)
    local list = c and tags.list(c.tags) or {}
    return (#list == tags.COUNT) and "all tags" or ("tag " .. table.concat(list, "+"))
end

--------------------------------------------------------------------------------
-- Start / stop
--------------------------------------------------------------------------------

function API:start()
    local spoon = self.spoon
    local tags = spoon.tags

    -- Starting twice would double every subscription; tear down the previous run first
    if self.started then self:stop() end
    self.started = true

    -- hs.window.filter.default silently drops whole categories of apps before we ever see them.
    -- Use our own filter instead: every visible window of a role we can manage gets through, and
    -- rules decide what happens to each one. Other roles (popups, menus, banners, alerts) are never
    -- managed, so letting them through would only generate events and relayouts.
    local windowFilter = hs.window.filter.new(true):setDefaultFilter({
        visible = true,
        allowRoles = { "AXStandardWindow", "AXDialog", "AXSystemDialog", "AXFloatingWindow" },
    })
    self.windowFilter = windowFilter
    local function subscribe(event, fn) windowFilter:subscribe(event, fn) end

    if spoon.menubar then spoon.menubar:start() end

    -- Layout requests coalesce: a burst of window events costs one layout pass
    local layoutPending = false
    local function scheduleLayout(source)
        if spoon.state.viewChanging then
            spoon.state.layoutDeferred = true
            return
        end
        if layoutPending then return end
        layoutPending = true
        hs.timer.doAfter(spoon.config.timing.layoutUpdateDelay, function()
            layoutPending = false
            if spoon.state.viewChanging then
                spoon.state.layoutDeferred = true
                return
            end
            spoon.helpers:log("debug", "layout pass (" .. tostring(source) .. ")")
            spoon:updateLayout()
            if spoon.menubar then spoon.menubar:update() end
        end)
    end

    -- Restore the last session BEFORE subscribing to the window filter, otherwise existing windows
    -- get registered again as new ones
    if spoon.state.pendingTags then tags:restore(spoon.state.pendingTags) end
    spoon.state.pendingTags = nil

    -- Apply the rules to a window: track it (tiled or floating, on its tags) or ignore it.
    -- Also used to re-check shortly after creation, when title/subrole/buttons often aren't final yet.
    local function processWindow(win, isRecheck)
        local winId = spoon.helpers:getWindowId(win)
        if not winId then return end

        -- A float/tile choice made by hand always wins over rules
        if isRecheck and tags:isManuallyFloated(winId) then return end

        local result = spoon.rules:classify(win)
        local client = tags:getClient(winId)
        local before = client and (client.floating and "float" or "tile") or "ignore"
        if spoon.config.debug and (not isRecheck or before ~= result.manage) then
            -- Only cheap lookups here: describe() would query the accessibility tree for every window
            local appOk, appName = pcall(function() return win:application():name() end)
            local titleOk, title = pcall(function() return win:title() end)
            local roleOk, subrole = pcall(function() return win:subrole() end)
            print(string.format("[WM rules] %s | %q | subrole=%s -> %s (%s)%s",
                appOk and appName or "?", titleOk and title or "?", roleOk and tostring(subrole) or "?",
                result.manage, tostring(result.rule or "no rule"), isRecheck and " [recheck]" or ""))
        end

        if result.manage == "ignore" then
            if client then
                tags:remove(winId)
                scheduleLayout("windowIgnored")
            end
            return
        end

        local floating = result.manage == "float"
        if not client then
            client = tags:register(win, result.tags, { floating = floating })
            if not client then return end
            -- A rule can send a window to tags that aren't in view: park it right away
            if not tags:isVisible(client) then tags:hide(client) end
        elseif client.floating ~= floating then
            tags:setFloating(winId, floating)
        end

        -- Geometry only makes sense for floating windows; tiled ones are placed by the layout
        if floating and not isRecheck then
            local ok, frame = pcall(function() return win:frame() end)
            local screen = hs.screen.mainScreen()
            if ok and frame and screen and (result.dimensions or result.position or result.center) then
                local new = { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
                if result.dimensions then new.w, new.h = result.dimensions[1], result.dimensions[2] end
                if result.position then new.x, new.y = result.position[1], result.position[2] end
                if result.center then
                    local sf = screen:frame()
                    new.x, new.y = sf.x + (sf.w - new.w) / 2, sf.y + (sf.h - new.h) / 2
                end
                pcall(win.setFrame, win, new)
            end
        end

        scheduleLayout(isRecheck and "windowRecheck" or "windowCreated")
    end

    subscribe(hs.window.filter.windowCreated, function(win)
        if not win then return end
        processWindow(win, false)

        -- Titles, subroles and buttons are often not final at creation: look again once things settle
        local winId = spoon.helpers:getWindowId(win)
        hs.timer.doAfter(spoon.config.timing.ruleRecheckDelay or 0.4, function()
            if winId and spoon.helpers:getWindowId(win) == winId then processWindow(win, true) end
        end)
    end)

    -- Window destroyed - forget it
    subscribe(hs.window.filter.windowDestroyed, function(win)
        local winId = win and spoon.helpers:getWindowId(win)
        if winId then tags:remove(winId) else tags:prune() end
        scheduleLayout("windowDestroyed")

        -- Closing a window must leave you where you are. macOS re-activates the previously active
        -- app, whose key window is usually parked on tags that aren't in view: don't follow that, and
        -- put focus on something visible instead (the next window here, or the desktop if none is left).
        spoon.state.windowClosedUntil = hs.timer.secondsSinceEpoch() + 0.6
        hs.timer.doAfter(0.1, function()
            local focused = tags:getClient(spoon.helpers:getWindowId(hs.window.focusedWindow()))
            if focused and not tags:isVisible(focused) then tags:focusCurrent() end
        end)
    end)

    -- Window minimized/unminimized
    subscribe(hs.window.filter.windowMinimized, function(win)
        -- Minimizing moves focus: don't read that as a request to change the view
        spoon.state.justMinimized = true
        hs.timer.doAfter(0.15, function() spoon.state.justMinimized = false end)
        tags:setMinimized(spoon.helpers:getWindowId(win), true)
        scheduleLayout("windowMinimized")
    end)

    subscribe(hs.window.filter.windowUnminimized, function(win)
        local winId = spoon.helpers:getWindowId(win)
        tags:setMinimized(winId, false)
        local c = tags:getClient(winId)
        if c and not tags:isVisible(c) then tags:hide(c) end -- Restored on tags that aren't in view
        scheduleLayout("windowUnminimized")
    end)

    local lastFocusedWinId = nil
    local lastFocusTime = 0
    subscribe(hs.window.filter.windowFocused, function(win)
        local winId = spoon.helpers:getWindowId(win)
        local client = tags:getClient(winId)
        if not client then return end -- Ignored windows are none of our business

        -- The filter reports the already-focused window when it starts: that is not a user action
        if not spoon.state.ready then return end
        if hs.timer.secondsSinceEpoch() < (spoon.state.windowClosedUntil or 0) then return end

        -- Skip focus handling during view changes, right after minimize and while the stack rotates
        if spoon.state.viewChanging or spoon.state.justMinimized or spoon.state.rotatingStack then return end

        -- Focusing a window that is not in view (Dock click, Cmd+Tab, Spotlight) shows its tags, like
        -- dwm's focusonnetactive. Silent: this isn't a keypress, so no alert.
        if not tags:isVisible(client) then
            spoon.helpers:log("debug", string.format("focus: window %d is on tags %s, viewing them",
                winId, table.concat(tags.list(client.tags), "+")))
            tags:noteFocus(winId) -- Land on the window the user asked for
            self:viewTags(client.tags, true)
            lastFocusedWinId = winId
            return
        end

        tags:noteFocus(winId)

        -- Focusing another tiled window ends the zoom (it would stay hidden behind the zoomed one).
        -- Floating windows, such as a dialog of the zoomed app, don't.
        local zoomed = tags:getZoomed()
        if zoomed and zoomed.id ~= winId and not client.floating then
            tags:setZoomed(zoomed.id, false)
            spoon:updateLayout()
            if spoon.menubar then spoon.menubar:update() end
        end

        -- Prevent focus loop: skip if same window focused again
        if winId == lastFocusedWinId then return end

        -- Debounce rapid focus changes (prevent loops)
        local now = hs.timer.secondsSinceEpoch()
        if now - lastFocusTime < 0.1 then return end
        lastFocusTime = now
        lastFocusedWinId = winId

        -- For Scroll: scroll to show the focused window's column
        local layouts = spoon.layoutsModule
        if layouts and spoon:getCurrentLayoutName() == "scroll" then
            local colIdx = layouts:scrollFindWindow(winId)
            -- Only update if offset actually changed to prevent focus loops
            if colIdx and layouts.scrollViewOffset ~= colIdx - 1 then
                layouts.scrollViewOffset = colIdx - 1
                spoon:updateLayout()
            end
        end

        pcall(win.raise, win)
        spoon.ui:updateAll()
    end)

    subscribe(hs.window.filter.windowMoved, function(win)
        -- Our own layout and view changes move windows too: only react to the user moving a tiled window
        if spoon.state.viewChanging or spoon.state.dragging then return end
        if hs.timer.secondsSinceEpoch() - (spoon.state.layoutAppliedAt or 0) < 0.25 then return end

        local c = tags:getClient(spoon.helpers:getWindowId(win))
        if c and not c.floating and not c.parked and tags:isVisible(c) then
            scheduleLayout("windowMoved")
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
            spoon.state.dragging = dragWin ~= nil
            originalFrames = {}
            -- Original frames of all tiled windows: the drop target is found in these
            for _, w in ipairs(spoon.state.windows) do
                originalFrames[w:id()] = w:frame()
            end
        end
        return false
    end)

    spoon.dragEndTap = hs.eventtap.new({ hs.eventtap.event.types.leftMouseUp }, function(e)
        -- Only treat as a window drag if the window itself moved. Drags inside an
        -- app (text selection, scrollbars, sliders) must never trigger a swap.
        local moved = false
        if dragWin and dragStartFrame then
            local ok, cur = pcall(function() return dragWin:frame() end)
            if ok and cur then
                moved = math.abs(cur.x - dragStartFrame.x) > DRAG_MOVE_THRESHOLD
                    or math.abs(cur.y - dragStartFrame.y) > DRAG_MOVE_THRESHOLD
            end
        end

        if moved then
            local winId = dragWin:id()
            local mousePos = hs.mouse.absolutePosition()
            local windows = spoon.state.windows
            local srcIdx, dstIdx
            for i, w in ipairs(windows) do
                local id = w:id()
                if id == winId then
                    srcIdx = i
                elseif not dstIdx then
                    local f = originalFrames[id]
                    if f and mousePos.x >= f.x and mousePos.x <= f.x + f.w
                        and mousePos.y >= f.y and mousePos.y <= f.y + f.h then
                        dstIdx = i
                    end
                end
            end

            if srcIdx and dstIdx and not tags:isFloating(winId) and not tags:getZoomed() then
                spoon.core:swapIndices(srcIdx, dstIdx)
                spoon.core:showAlert("Swapped")
                spoon.core:updateLayout()
            else
                scheduleLayout("dragEnd") -- Dropped nowhere useful: snap back
            end
        end

        spoon.state.dragging = false
        dragWin, dragStartFrame, originalFrames = nil, nil, {}
        return false
    end)

    spoon.dragTap:start()
    spoon.dragEndTap:start()

    -- macOS Space changes can move windows around
    self.spaceWatcher = hs.spaces.watcher.new(function()
        hs.timer.doAfter(spoon.config.timing.spaceChangeDelay, function() scheduleLayout("spaceChanged") end)
    end):start()

    -- Initial setup
    hs.timer.doAfter(spoon.config.timing.initialSetupDelay, function()
        tags:syncExisting() -- Windows we didn't restore join the tags in view

        spoon.state.ready = true -- From here on, settings may be written and focus changes are followed
        spoon:updateLayout()
        if spoon.menubar then spoon.menubar:update() end

        -- After a reload the focused window can be one parked on tags that aren't in view (it kept
        -- key status while hidden): hand focus to a window we are actually showing
        local focused = tags:getClient(spoon.helpers:getWindowId(hs.window.focusedWindow()))
        if focused and not tags:isVisible(focused) then tags:focusCurrent() end

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
            ruleRecheckDelay = 0.4
        }
        for field, defaultVal in pairs(timingDefaults) do
            if timing[field] ~= nil and (type(timing[field]) ~= "number" or timing[field] < 0) then
                table.insert(warnings, "timing." .. field .. " invalid, using default " .. defaultVal)
                timing[field] = defaultVal
            end
        end
    end

    if config.newWindow ~= nil and config.newWindow ~= "master" and config.newWindow ~= "last" then
        table.insert(warnings, 'newWindow must be "master" or "last", using "master"')
        config.newWindow = "master"
    end
    for _, key in ipairs({ "scroll", "commands" }) do
        if config[key] ~= nil and type(config[key]) ~= "table" then
            table.insert(warnings, key .. " must be a table, ignoring")
            config[key] = nil
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

-- Force retile: rebuild every column structure and re-scan windows. Tags are kept.
function API:forceRetile()
    local spoon = self.spoon
    local tags = spoon.tags

    tags:rescan() -- Drop dead windows, adopt unknown ones into the tags in view
    for i = 0, tags.COUNT do
        local st = tags.pertag[i]
        st.tileColumns, st.scrollColumns, st.scrollViewOffset = {}, {}, 0
    end
    tags:loadLive()

    tags:applyVisibility()
    spoon:updateLayout()
    if spoon.menubar then spoon.menubar:update() end
    spoon.core:showAlert("Retiled")

    return spoon
end

-- Stop everything start() set up. Safe to call more than once.
function API:stop()
    local spoon = self.spoon

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
