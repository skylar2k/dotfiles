-- WM Tags
-- dwm-style tags: every window carries a set of tags (a bitmask), and the *view* is the set of tags
-- being shown. A window is visible when its tags overlap the view, so several tags can be shown at
-- once and one window can live in several tags.
--
-- Semantics follow dwm with the pertag patch:
--   * two tagsets + `seltags` let you flip back to the previous view
--   * `curtag` is the tag whose settings are active: the lowest tag of the view, or 0 for "all tags"
--   * layout state (layout, columns, scroll offset) is kept per tag, not per combination of tags
--   * a new window gets the tags that are currently in view

local Tags = {}
Tags.__index = Tags

local COUNT = 9
local ALL = (1 << COUNT) - 1
Tags.COUNT = COUNT
Tags.ALL = ALL

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Bitmask of a single tag (1..9)
function Tags.bit(index)
    return 1 << (index - 1)
end

--- Bitmask from a tag number or a list of tag numbers; nil if anything is out of range
function Tags.toMask(value)
    local list = type(value) == "table" and value or { value }
    local mask = 0
    for _, i in ipairs(list) do
        if type(i) ~= "number" or i < 1 or i > COUNT or i % 1 ~= 0 then return nil end
        mask = mask | Tags.bit(i)
    end
    if mask == 0 then return nil end
    return mask
end

--- Lowest tag number set in a mask
function Tags.lowest(mask)
    for i = 1, COUNT do
        if mask & Tags.bit(i) ~= 0 then return i end
    end
end

--- Tag numbers set in a mask, ascending
function Tags.list(mask)
    local list = {}
    for i = 1, COUNT do
        if mask & Tags.bit(i) ~= 0 then list[#list + 1] = i end
    end
    return list
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

local function newTagState()
    return { layout = 1, tileColumns = {}, scrollColumns = {}, scrollViewOffset = 0 }
end

-- A client is alive while its window object still answers with its own id
local function alive(c)
    local ok, id = pcall(c.win.id, c.win)
    return ok and id == c.id
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

function Tags:new(spoon)
    local o = setmetatable({}, self)
    o.spoon = spoon
    o.clients = {}       -- winId -> { id, win, tags, floating, manual, minimized, parked, seq, focusSeq, frame }
    o.tailSeq = 1        -- Client order is a sequence number: new windows go before the head (dwm attach) ...
    o.headSeq = 0        -- ... or after the tail, depending on `newWindow`
    o.focusCounter = 0   -- Focus recency counter
    o.tagset = { 1, 1 }  -- dwm: tagset[seltags] is the current view, the other one the previous view
    o.seltags = 1
    o.curtag, o.prevtag = 1, 1
    o.pertag = {}        -- [0] = all tags, [1..9] = one tag
    for i = 0, COUNT do o.pertag[i] = newTagState() end
    return o
end

--------------------------------------------------------------------------------
-- Views
--------------------------------------------------------------------------------

function Tags:viewMask()
    return self.tagset[self.seltags]
end

-- dwm's ISVISIBLE, plus the scratchpad: a sticky window is visible whatever the view, and a dismissed
-- scratchpad is not visible at all
local function shows(c, mask)
    return not c.hidden and (c.sticky or c.tags & mask ~= 0)
end

function Tags:isVisible(c)
    return shows(c, self.tagset[self.seltags])
end

--- Settings of the current tag
function Tags:getPertag()
    return self.pertag[self.curtag]
end

--- Live layout state lives in the layouts module; park it in the per-tag slot before switching away
function Tags:saveLive()
    local lm = self.spoon.layoutsModule
    if not lm then return end
    local st = self.pertag[self.curtag]
    st.tileColumns, st.scrollColumns, st.scrollViewOffset = lm.tileColumns, lm.scrollColumns, lm.scrollViewOffset
end

function Tags:loadLive()
    local lm = self.spoon.layoutsModule
    if not lm then return end
    local st = self.pertag[self.curtag]
    lm.tileColumns, lm.scrollColumns, lm.scrollViewOffset = st.tileColumns, st.scrollColumns, st.scrollViewOffset
end

-- dwm: prevtag always becomes the old curtag; the per-tag state only needs swapping if it differs
local function changeCurtag(self, newCurtag)
    local old = self.curtag
    if newCurtag ~= old then self:saveLive() end
    self.prevtag = old
    self.curtag = newCurtag
    if newCurtag ~= old then self:loadLive() end
end

--- dwm `view`: show exactly these tags. 0 flips back to the previous view.
--- Returns true if the view changed.
function Tags:view(mask)
    mask = mask & ALL
    if mask ~= 0 and mask == self:viewMask() then return false end

    self.seltags = 3 - self.seltags
    if mask ~= 0 then
        self.tagset[self.seltags] = mask
        changeCurtag(self, mask == ALL and 0 or Tags.lowest(mask))
    else
        -- Previous view: its tag settings come back with it (swap curtag and prevtag)
        self:saveLive()
        self.curtag, self.prevtag = self.prevtag, self.curtag
        self:loadLive()
    end
    return true
end

--- dwm `toggleview`: add or remove tags from the view. Returns true if the view changed.
function Tags:toggleView(mask)
    local new = self:viewMask() ~ (mask & ALL)
    if new == 0 then return false end

    self.tagset[self.seltags] = new
    if new == ALL then
        changeCurtag(self, 0)
    elseif self.curtag == 0 or new & Tags.bit(self.curtag) == 0 then
        changeCurtag(self, Tags.lowest(new))
    end
    return true
end

--------------------------------------------------------------------------------
-- Clients
--------------------------------------------------------------------------------

function Tags:getClient(winId)
    return winId and self.clients[winId]
end

--- Start tracking a window. opts: { floating = bool, frame = {x,y,w,h}, attach = "master" | "last" }.
--- New windows become the master, as in dwm, unless `newWindow = "last"` is configured.
--- Returns the client, or nil if the window is invalid or already tracked.
function Tags:register(win, mask, opts)
    opts = opts or {}
    local winId = safeWindowId(win)
    if not winId or self.clients[winId] then return nil end
    mask = (mask or self:viewMask()) & ALL
    if mask == 0 then mask = self:viewMask() end

    local minOk, minimized = pcall(function() return win:isMinimized() end)
    local c = {
        id = winId,
        win = win,
        tags = mask,
        floating = opts.floating and true or false,
        manual = false,
        minimized = minOk and minimized or false,
        parked = false,
        seq = 0,
        focusSeq = 0,
        frame = plainFrame(opts.frame),
    }
    if (opts.attach or self.spoon.config.newWindow or "master") == "last" then
        c.seq, self.tailSeq = self.tailSeq, self.tailSeq + 1
    else
        c.seq, self.headSeq = self.headSeq, self.headSeq - 1
    end
    self.clients[winId] = c
    return c
end

function Tags:remove(winId)
    if not self.clients[winId] then return false end
    self.clients[winId] = nil
    return true
end

--- Drop clients whose window no longer exists
function Tags:prune()
    for id, c in pairs(self.clients) do
        if not alive(c) then self.clients[id] = nil end
    end
end

--- The only place that changes a window's floating state. `manual` marks a user decision,
--- which rules never override afterwards.
function Tags:setFloating(winId, floating, manual)
    local c = self.clients[winId]
    if not c then return end
    c.floating = floating and true or false
    if manual then c.manual = true end
end

function Tags:isFloating(winId)
    local c = self.clients[winId]
    return c ~= nil and c.floating
end

function Tags:isManuallyFloated(winId)
    local c = self.clients[winId]
    return c ~= nil and c.manual
end

--- Tracked, in view and not floating
function Tags:isTiled(winId)
    local c = self.clients[winId]
    return c ~= nil and not c.floating and self:isVisible(c)
end

function Tags:setMinimized(winId, minimized)
    local c = self.clients[winId]
    if c then c.minimized = minimized and true or false end
end

--- dwm `tag`: put a window on exactly these tags (the view does not change)
function Tags:setWindowTags(winId, mask)
    local c = self.clients[winId]
    mask = mask & ALL
    if not c or mask == 0 or mask == c.tags then return false end
    c.tags = mask
    return true
end

--- dwm `toggletag`: add or remove tags on a window; a window always keeps at least one tag
function Tags:toggleWindowTag(winId, mask)
    local c = self.clients[winId]
    if not c then return false end
    local new = c.tags ~ (mask & ALL)
    if new == 0 then return false end
    c.tags = new
    return true
end

--- dwm sticky patch: a sticky window is visible on all tags, but keeps the tags it really has, so
--- toggling it off puts it back where it came from. Returns the new state, or nil for unknown windows.
function Tags:toggleSticky(winId)
    local c = self.clients[winId]
    if not c then return nil end
    c.sticky = not c.sticky
    return c.sticky
end

--- Zoom: a window temporarily fills the screen. Layout state is untouched, so un-zooming puts every
--- window back exactly where it was. Only one window is zoomed per view.
function Tags:setZoomed(winId, zoomed)
    local c = self.clients[winId]
    if not c then return false end

    if zoomed then
        local view = self:viewMask()
        for _, other in pairs(self.clients) do
            if other ~= c and other.zoomed and shows(other, view) then self:setZoomed(other.id, false) end
        end
        if not c.zoomed then
            local ok, frame = pcall(c.win.frame, c.win)
            c.zoomFrame = ok and plainFrame(frame) or nil
        end
        c.zoomed = true
    elseif c.zoomed then
        c.zoomed = false
        -- Tiled windows are put back by the layout; floating ones go back to where they were
        if c.floating and c.zoomFrame then pcall(c.win.setFrame, c.win, c.zoomFrame) end
        c.zoomFrame = nil
    end
    return true
end

--- The zoomed window in view, if any
function Tags:getZoomed()
    local view = self:viewMask()
    local best
    for _, c in pairs(self.clients) do
        if c.zoomed and shows(c, view) and not c.minimized and (not best or c.focusSeq > best.focusSeq) then
            best = c
        end
    end
    if best and alive(best) then return best end
end

--- Scratchpad (like dwm's scratchpad patch): one floating window you summon to the current view and
--- dismiss again. It is not tied to any tag: summoning it moves it to the tags in view.
function Tags:setScratchpad(winId)
    local c = self.clients[winId]
    if not c then return false end
    for _, other in pairs(self.clients) do other.scratch = false end -- Only one at a time
    c.scratch = true
    c.floating = true
    return true
end

function Tags:getScratchpad()
    for _, c in pairs(self.clients) do
        if c.scratch and alive(c) then return c end
    end
end

--- Where the scratchpad appears: centered, config.scratchpad.width/height of the screen
function Tags:scratchFrame()
    local screen = hs.screen.mainScreen()
    if not screen then return nil end
    local f, config = screen:frame(), self.spoon.config.scratchpad or {}
    local w, h = f.w * (config.width or 0.6), f.h * (config.height or 0.6)
    return { x = f.x + (f.w - w) / 2, y = f.y + (f.h - h) / 2, w = w, h = h }
end

--- Dismiss the scratchpad if it is showing, otherwise summon it to the current view.
--- Returns "hidden", "shown", or nil when there is no scratchpad window.
function Tags:toggleScratchpad()
    local c = self:getScratchpad()
    if not c then return nil end

    if self:isVisible(c) then
        c.hidden = true
        return "hidden"
    end

    c.hidden = false
    c.tags = self:viewMask()
    c.frame = self:scratchFrame() -- Applied when the window is brought back from its parking spot
    self:noteFocus(c.id)
    return "shown"
end

function Tags:noteFocus(winId)
    local c = self.clients[winId]
    if not c then return end
    self.focusCounter = self.focusCounter + 1
    c.focusSeq = self.focusCounter
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------

local function bySeq(a, b) return a.seq < b.seq end

--- Windows to tile: in view, not floating, not minimized, in stable client order
function Tags:getVisibleTiled()
    local view = self:viewMask()
    local list = {}
    for _, c in pairs(self.clients) do
        if shows(c, view) and not c.floating and not c.minimized and alive(c) then
            list[#list + 1] = c
        end
    end
    table.sort(list, bySeq)
    for i, c in ipairs(list) do list[i] = c.win end
    return list
end

--- Floating windows in view
function Tags:getVisibleFloating()
    local view = self:viewMask()
    local list = {}
    for _, c in pairs(self.clients) do
        if shows(c, view) and c.floating and not c.minimized and alive(c) then
            list[#list + 1] = c.win
        end
    end
    return list
end

--- Number of windows carrying a tag, or showing in the current view when no tag is given
function Tags:count(tag)
    local view, bit, n = self:viewMask(), tag and Tags.bit(tag), 0
    for _, c in pairs(self.clients) do
        if (bit and c.tags & bit ~= 0) or (not bit and shows(c, view)) then n = n + 1 end
    end
    return n
end

--- Mask of every tag that has at least one window
function Tags:occupied()
    local mask = 0
    for _, c in pairs(self.clients) do mask = mask | c.tags end
    return mask
end

--- Put the given windows (a subset of the clients) in this order, keeping the slots they already occupy
--- in the global client order
function Tags:setOrder(windows)
    local picked, seqs = {}, {}
    for _, win in ipairs(windows) do
        local c = self.clients[safeWindowId(win)]
        if c then
            picked[#picked + 1] = c
            seqs[#seqs + 1] = c.seq
        end
    end
    table.sort(seqs)
    for i, c in ipairs(picked) do c.seq = seqs[i] end
end

--------------------------------------------------------------------------------
-- Showing and hiding
--------------------------------------------------------------------------------

--- Off-screen parking spot: bottom-right corner, 1px visible
function Tags:getOffScreenPosition()
    local screen = hs.screen.mainScreen()
    if not screen then return { x = 10000, y = 10000 } end
    local f = screen:frame()
    return { x = f.x + f.w - 1, y = f.y + f.h - 1 }
end

function Tags:hide(c)
    if c.parked or c.minimized then return end
    local ok, frame = pcall(c.win.frame, c.win)
    if ok then c.frame = plainFrame(frame) end
    pcall(c.win.setTopLeft, c.win, self:getOffScreenPosition())
    c.parked = true
end

function Tags:show(c)
    if not c.parked then return end
    c.parked = false
    -- Tiled windows are placed by the layout right after; everything else gets its old frame back
    local layoutPlaces = not c.floating and self.spoon.state.tileEnabled ~= false
    if not layoutPlaces and c.frame and c.frame.w > 0 then
        pcall(c.win.setFrame, c.win, c.frame)
    end
end

--- Park every window outside the view, bring back every window inside it
function Tags:applyVisibility()
    local view = self:viewMask()
    local hidden = {}
    for _, c in pairs(self.clients) do
        if shows(c, view) then
            self:show(c)
        else
            hidden[#hidden + 1] = c
        end
    end
    -- Hide last so the screen never shows an empty gap while windows are being shown
    for _, c in ipairs(hidden) do self:hide(c) end
end

--- Give keyboard focus to the most recently used window in view, or to the desktop when there is none.
--- Parked windows must never keep focus: the app owning the focused window owns the macOS menu bar,
--- and whenever that app is re-activated macOS hands focus back to its (parked) window.
function Tags:focusCurrent()
    local view = self:viewMask()
    local best
    for _, c in pairs(self.clients) do
        if shows(c, view) and not c.minimized then
            if not best or c.focusSeq > best.focusSeq or (c.focusSeq == best.focusSeq and c.seq < best.seq) then
                best = c
            end
        end
    end

    local target = best and best.win
    if not target then
        local ok, desktop = pcall(hs.window.desktop)
        target = ok and desktop or nil
    end
    if target then pcall(target.focus, target) end
end

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

function Tags:serialize()
    self:saveLive()

    local pertag = {}
    for i = 0, COUNT do
        local st = self.pertag[i]
        -- String keys: index 0 would turn the array into an object, and decoding returns strings anyway
        pertag[tostring(i)] = {
            layout = st.layout,
            tileColumns = st.tileColumns,
            scrollColumns = st.scrollColumns,
            scrollViewOffset = st.scrollViewOffset,
        }
    end

    local clients = {}
    for id, c in pairs(self.clients) do
        clients[tostring(id)] = {
            tags = c.tags,
            floating = c.floating,
            manual = c.manual or nil,
            scratch = c.scratch or nil,
            hidden = c.hidden or nil,
            sticky = c.sticky or nil,
            seq = c.seq,
            focusSeq = c.focusSeq,
            frame = c.frame,
        }
    end

    return {
        tagset = { self.tagset[1], self.tagset[2] },
        seltags = self.seltags,
        curtag = self.curtag,
        prevtag = self.prevtag,
        pertag = pertag,
        clients = clients,
    }
end

--- Restore a saved session. Windows that no longer exist are dropped; rules are re-applied so edits to
--- them take effect on reload (a float/tile choice made by hand is kept).
--- Must run before the window filter starts so existing windows aren't re-registered.
function Tags:restore(data)
    if type(data) ~= "table" or type(data.clients) ~= "table" then return false end

    for key, st in pairs(data.pertag or {}) do
        local i = tonumber(key)
        if i and self.pertag[i] and type(st) == "table" then
            self.pertag[i] = {
                layout = st.layout or 1,
                tileColumns = st.tileColumns or {},
                scrollColumns = st.scrollColumns or {},
                scrollViewOffset = st.scrollViewOffset or 0,
            }
        end
    end

    local function validMask(m)
        m = tonumber(m)
        return m and m & ALL ~= 0 and m & ALL or nil
    end
    local set1, set2 = validMask(data.tagset and data.tagset[1]), validMask(data.tagset and data.tagset[2])
    if set1 and set2 then
        self.tagset = { set1, set2 }
        self.seltags = (data.seltags == 2) and 2 or 1
    end
    local curtag, prevtag = tonumber(data.curtag), tonumber(data.prevtag)
    if curtag and self.pertag[curtag] then self.curtag = curtag end
    if prevtag and self.pertag[prevtag] then self.prevtag = prevtag end
    self:loadLive()

    -- One window listing for the whole restore instead of a lookup per window
    local byId = {}
    for _, win in ipairs(hs.window.allWindows()) do
        local id = safeWindowId(win)
        if id then byId[id] = win end
    end

    local view = self:viewMask()
    local restored = 0
    for idStr, saved in pairs(data.clients) do
        local winId = tonumber(idStr)
        local win = winId and byId[winId]
        if win and not self.clients[winId] then
            local result = self.spoon.rules:classify(win)
            if result.manage ~= "ignore" then
                local floating = result.manage == "float"
                if saved.manual then floating = saved.floating or false end
                local c = self:register(win, validMask(saved.tags) or self:viewMask(), { floating = floating, frame = saved.frame })
                if c then
                    c.manual = saved.manual or false
                    c.scratch = saved.scratch or false
                    c.hidden = saved.hidden or false
                    c.sticky = saved.sticky or false
                    c.seq = tonumber(saved.seq) or c.seq
                    c.focusSeq = tonumber(saved.focusSeq) or 0
                    c.parked = not shows(c, view) -- Windows outside the view were parked when we last ran
                    self.tailSeq = math.max(self.tailSeq, c.seq + 1)
                    self.headSeq = math.min(self.headSeq, c.seq - 1)
                    self.focusCounter = math.max(self.focusCounter, c.focusSeq)
                    restored = restored + 1
                end
            end
        end
    end

    return restored > 0
end

--- Adopt windows we don't know about, as decided by the rules. They join the tags in view,
--- unless a rule says otherwise.
function Tags:syncExisting()
    local screen = hs.screen.mainScreen()
    local sf = screen and screen:frame()
    local view = self:viewMask()

    for _, win in ipairs(hs.window.allWindows()) do
        local winId = safeWindowId(win)
        if winId and not self.clients[winId] then
            local result = self.spoon.rules:classify(win)
            if result.manage ~= "ignore" then
                local ok, frame = pcall(function() return win:frame() end)
                frame = ok and frame or nil

                -- A window parked off-screen by a previous session that we can't place: bring it back
                if frame and sf and frame.x >= sf.x + sf.w - 2 and frame.y >= sf.y + sf.h - 2 then
                    frame = { x = sf.x + sf.w * 0.2, y = sf.y + sf.h * 0.2, w = sf.w * 0.6, h = sf.h * 0.6 }
                    pcall(win.setFrame, win, frame)
                end

                -- Windows that were already open keep the order the system lists them in
                local c = self:register(win, result.tags or self:viewMask(),
                    { floating = result.manage == "float", frame = frame, attach = "last" })
                if c and not shows(c, view) then self:hide(c) end
            end
        end
    end
end

--- Re-scan all windows without losing tags: drop dead windows, adopt unknown ones
function Tags:rescan()
    self:prune()
    self:syncExisting()
end

return Tags
