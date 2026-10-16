hs.loadSpoon("SpoonInstall")
hs.loadSpoon("EmmyLua")

hs.window.animationDuration = 0
local wm = hs.loadSpoon("wm")

wm:configure({
    gap = 8,
    usePerSpaceLayouts = true,

    menubar = {
        enabled = true,
        showWindowCount = true,
    },

})

local wm_hotkeys = {
    showLayoutInfo = { { "cmd", "alt" }, "b" },
    forceRetile = { { "cmd", "alt" }, "r" },
}

-- Workspaces 1-9: cmd+alt+N focuses, cmd+alt+shift+N moves the window and follows
for i = 1, 9 do
    wm_hotkeys["focusWorkspace" .. i] = { { "cmd", "alt" }, tostring(i) }
    wm_hotkeys["moveToWorkspace" .. i] = { { "cmd", "alt", "shift" }, tostring(i) }
end

wm:bindHotkeys(wm_hotkeys)

wm:start()
