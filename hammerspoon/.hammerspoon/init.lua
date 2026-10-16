hs.loadSpoon("SpoonInstall")
hs.loadSpoon("EmmyLua")

local wm = hs.loadSpoon("wm")

wm:configure({
    gap = 8,
    debug = true,

    menubar = {
        enabled = true,
        showWindowCount = true,
    },

    rules = {
        { app_id = "com.apple.finder",  action = "float" },
        { app_id = "com.apple.Preview", action = "float", dimensions = { 900, 700 }, center = true },
    },
})

--------------------------------------------------------------------------------
-- Keybindings (Nordic layout, Caps Lock = Alt)
--
-- Why alt+cmd and not plain alt: on Nordic Mac layouts Option types @ $ | [ ] { } ~ \
-- so a global alt+<key> hotkey would eat those characters. alt+cmd types nothing.
-- Only letters, digits, arrows, space and return are used: they sit in the same place on
-- every Nordic variant, while keys like å ø æ ¨ ' are named by the active input source.
--
--   main          focus / layout / view a tag
--   main+shift    move things (swap, move column, tag the window)
--   main+ctrl     resize (hjkl) / toggle a tag in the view
--
-- Tags work like dwm: windows carry tags, the view is the set of tags being shown.
--   main+N              view tag N only                (dwm view)
--   main+ctrl+N         add/remove tag N in the view   (dwm toggleview)
--   main+shift+N        put the window on tag N        (dwm tag)
--   main+ctrl+shift+N   add/remove tag N on the window (dwm toggletag)
--   main+0 / main+shift+0   view all tags / put the window on all tags
--   main+tab            back to the previous view
--------------------------------------------------------------------------------
local main = { "alt", "cmd" }
local function mods(...) -- main + extra modifiers
    local m = { table.unpack(main) }
    for _, extra in ipairs({ ... }) do m[#m + 1] = extra end
    return m
end

local wm_hotkeys = {
    -- Focus: j/k = next/previous window, h/l = scroll columns left/right (scroll layout)
    focusNext = { main, "j" },
    focusPrev = { main, "k" },
    scrollLeft = { main, "h" },
    scrollRight = { main, "l" },

    -- Move: shift + the same keys
    swapNext = { mods("shift"), "j" },
    swapPrev = { mods("shift"), "k" },
    moveColumnLeft = { mods("shift"), "h" },
    moveColumnRight = { mods("shift"), "l" },
    createColumn = { main, "return" },

    -- Resize: ctrl + hjkl
    resizeLeft = { mods("ctrl"), "h" },
    resizeDown = { mods("ctrl"), "j" },
    resizeUp = { mods("ctrl"), "k" },
    resizeRight = { mods("ctrl"), "l" },
    balanceLayout = { main, "b" },

    -- Layout
    cycleLayout = { main, "space" },
    chooseLayout = { mods("shift"), "t" },
    toggleTiling = { main, "t" },
    toggleFloatingWindow = { mods("shift"), "space" },
    toggleZoom = { main, "z" },

    -- Floating windows: arrows step through sizes, shift+arrows snap to halves
    floatingPositionLeft = { main, "left" },
    floatingPositionRight = { main, "right" },
    floatingPositionUp = { main, "up" },
    floatingPositionDown = { main, "down" },
    floatingHalfLeft = { mods("shift"), "left" },
    floatingHalfRight = { mods("shift"), "right" },
    floatingHalfTop = { mods("shift"), "up" },
    floatingHalfBottom = { mods("shift"), "down" },
    floatingCenter = { main, "c" },
    floatingMaximize = { main, "m" },
    floatingNextScreen = { main, "n" },

    -- Info / recovery
    showLayoutInfo = { main, "i" },
    showWindowInfo = { mods("shift"), "i" },
    forceRetile = { main, "r" },
}

-- Tags 1-9
-- (There is also tagWindowAndView1..9: tag the window and follow it. Unbound by default.)
for i = 1, 9 do
    local key = tostring(i)
    wm_hotkeys["viewTag" .. i] = { main, key }
    wm_hotkeys["toggleViewTag" .. i] = { mods("ctrl"), key }
    wm_hotkeys["tagWindow" .. i] = { mods("shift"), key }
    wm_hotkeys["toggleWindowTag" .. i] = { mods("ctrl", "shift"), key }
end
wm_hotkeys.viewAllTags = { main, "0" }
wm_hotkeys.tagWindowAll = { mods("shift"), "0" }
wm_hotkeys.viewPreviousTags = { main, "tab" }

wm:bindHotkeys(wm_hotkeys)

wm:start()
