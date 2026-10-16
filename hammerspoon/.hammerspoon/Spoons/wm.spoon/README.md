# LaWM

A tiling window manager for macOS using Hammerspoon.

## Features

- Three layouts: Tile, Scroll, Stack
- 9 virtual workspaces with window hiding
- Per-workspace layout memory
- Window rules for auto-assignment
- Mouse drag to swap windows
- Dock and Cmd+Tab integration
- Menubar workspace indicator
- Window picker across all workspaces

## Layouts

### Tile

Classic master-stack layout. First window takes 60% on the left, remaining windows stack on the right at 40%.

```
┌──────────┬──────┐
│          │  2   │
│    1     ├──────┤
│          │  3   │
└──────────┴──────┘
```

You can create additional columns and move windows between them.

### Scroll

Horizontal scrolling columns inspired by Niri. Shows up to 3 columns at once with a 60% center column and 20% side columns. Scroll left/right to navigate.

```
┌────┬────────┬────┐
│    │        │    │
│ 1  │   2    │ 3  │
│    │        │    │
└────┴────────┴────┘
```

### Stack

All windows occupy the same space. Only the focused window is visible. Use focus key to cycle through windows.

## Installation

1. Copy `LaWM.spoon` to `~/.hammerspoon/Spoons/`
2. Add configuration to `~/.hammerspoon/init.lua`

## Configuration

```lua
hs.window.animationDuration = 0

hs.loadSpoon("LaWM")

spoon.LaWM:configure({
    gap = 8,
    
    excludedApps = {
        "System Settings",
        "Calculator",
        "Hammerspoon"
    },
    
    windowRules = {
        ["Slack"] = { workspace = 3 },
        ["Music"] = { workspace = 4, floating = true },
    },
    
    modeColors = {
        tile = "#4A9EEB",
        scroll = "#9B59B6",
        stack = "#00FF00",
    },
    
    timing = {
        layoutUpdateDelay = 0.02,
        spaceChangeDelay = 0.03,
        initialSetupDelay = 0.05,
        windowLockDuration = 0.15
    },
    
    menubar = {
        enabled = true,
        workspaceNames = {
            [1] = "main",
            [2] = "web",
            [3] = "code",
        },
    },
})

local hyper = {"alt"}
local hyperShift = {"alt", "shift"}
local super = {"alt", "ctrl"}

spoon.LaWM:bindHotkeys({
    -- Layout
    chooseLayout = { hyper, "=" },
    toggleTiling = { hyper, "t" },
    toggleFloatingWindow = { hyper, "space" },
    balanceLayout = { hyper, "b" },
    toggleFullscreen = { hyper, "f" },
    forceRetile = { super, "r" },

    -- Focus
    focus = { hyper, "tab" },
    focusNext = { hyper, "tab" },
    focusPrev = { hyperShift, "tab" },

    -- Swap
    swapNext = { hyper, "]" },
    swapPrev = { hyper, "[" },

    -- Resize
    resizeLeft = { hyperShift, "left" },
    resizeRight = { hyperShift, "right" },
    resizeUp = { hyperShift, "up" },
    resizeDown = { hyperShift, "down" },

    -- Floating positions
    floatingPositionLeft = { hyper, "left" },
    floatingPositionRight = { hyper, "right" },
    floatingPositionUp = { hyper, "up" },
    floatingPositionDown = { hyper, "down" },
    floatingFullscreen = { hyper, "return" },
    floatingNextScreen = { hyper, "n" },

    -- Column management (Tile and Scroll)
    createColumn = { super, "n" },
    moveColumnLeft = { super, "[" },
    moveColumnRight = { super, "]" },

    -- Scroll navigation
    scrollLeft = { super, "left" },
    scrollRight = { super, "right" },

    -- Workspaces
    focusWorkspace1 = { hyper, "1" },
    focusWorkspace2 = { hyper, "2" },
    -- ... up to focusWorkspace9

    moveToWorkspace1 = { hyperShift, "1" },
    moveToWorkspace2 = { hyperShift, "2" },
    -- ... up to moveToWorkspace9
})

spoon.LaWM:start()
```

## Hotkeys

### Layout

| Action | Default |
|--------|---------|
| Choose layout | Alt + = |
| Toggle tiling | Alt + T |
| Toggle floating | Alt + Space |
| Balance layout | Alt + B |
| Toggle fullscreen | Alt + F |
| Force retile | Alt + Ctrl + R |

### Focus and Swap

| Action | Default |
|--------|---------|
| Focus next | Alt + Tab |
| Swap next | Alt + ] |
| Swap prev | Alt + [ |

### Resize

| Action | Default |
|--------|---------|
| Resize left | Alt + Shift + Left |
| Resize right | Alt + Shift + Right |
| Resize up | Alt + Shift + Up |
| Resize down | Alt + Shift + Down |

### Floating Positions

| Action | Default |
|--------|---------|
| Position left | Alt + Left |
| Position right | Alt + Right |
| Position up | Alt + Up |
| Position down | Alt + Down |
| Fullscreen cycle | Alt + Return |
| Next screen | Alt + N |

### Columns (Tile and Scroll)

| Action | Default |
|--------|---------|
| Create column | Alt + Ctrl + N |
| Move column left | Alt + Ctrl + [ |
| Move column right | Alt + Ctrl + ] |
| Scroll left | Alt + Ctrl + Left |
| Scroll right | Alt + Ctrl + Right |

### Workspaces

| Action | Default |
|--------|---------|
| Focus workspace 1-9 | Alt + 1-9 |
| Move to workspace 1-9 | Alt + Shift + 1-9 |

### Mouse

Drag a window onto another to swap their positions.

## Window Rules

Automatically assign apps to workspaces:

```lua
windowRules = {
    ["AppName"] = { 
        workspace = 3,
        floating = true,
    },
}
```

## Files

| File | Purpose |
|------|---------|
| init.lua | Entry point, configuration |
| core.lua | Window operations |
| api.lua | Hotkeys, event handlers |
| layouts.lua | Tile, Scroll, Stack layouts |
| workspace_manager.lua | Workspace management |
| helpers.lua | Window filtering |
| ui.lua | Visual indicators |
| menubar.lua | Menubar display |

## Troubleshooting

Windows not tiling: Press Alt + Ctrl + R to force retile, or check if the app is in excludedApps.

Windows missing: They may be on another workspace. Press Alt + 1-9 to check.

## License

MIT
