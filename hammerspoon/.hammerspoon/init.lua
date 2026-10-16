hs.loadSpoon("SpoonInstall")
hs.loadSpoon("EmmyLua")

local wm = hs.loadSpoon("wm")

wm:configure({
    gap = 8,
    usePerSpaceLayouts = true,

    menubar = {
        enabled = true,
        showWindowCount = true,
    },

})

wm:bindHotkeys({
    -- Workspaces
    focusWorkspace1 = { { "cmd", "alt" }, "1" },
    focusWorkspace2 = { { "cmd", "alt" }, "2" },

    showLayoutInfo = { { "cmd", "alt" }, "b" },
    forceRetile = { { "cmd", "alt" }, "r" },
})

wm:start()
