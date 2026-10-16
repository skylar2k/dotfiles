hs.loadSpoon("SpoonInstall")
hs.loadSpoon("EmmyLua")

local wm = hs.loadSpoon("wm")

wm:configure({
    gap = 8,
    usePerSpaceLayouts = true,
    debug = true,

    menubar = {
        enabled = true,
        showWindowCount = true,
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
--   main          focus / layout / workspaces
--   main+shift    move things (swap, move column, move window to workspace)
--   main+ctrl     resize (hjkl) / move window to workspace but stay
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
    toggleFullscreen = { main, "f" },

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

-- Workspaces 1-9: main+N focuses, +shift moves the window and follows it, +ctrl moves it and stays
for i = 1, 9 do
    local key = tostring(i)
    wm_hotkeys["focusWorkspace" .. i] = { main, key }
    wm_hotkeys["moveToWorkspace" .. i] = { mods("shift"), key }
    wm_hotkeys["moveToWorkspaceStay" .. i] = { mods("ctrl"), key }
end

wm:bindHotkeys(wm_hotkeys)

wm:start()
