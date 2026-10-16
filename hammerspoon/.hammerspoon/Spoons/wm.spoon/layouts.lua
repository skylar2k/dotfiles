-- Layout Functions for WM
local Layouts = {}
Layouts.__index = Layouts

function Layouts:new(config, spoonRef)
    local o = setmetatable({}, self)
    o.spoon = spoonRef -- Store reference to main spoon

    -- Tiling layout state (unified master/bsp replacement)
    o.tileColumns = {} -- Array of {windows = {winId...}, ratio = 0.6, rowRatios = {...}}
    o.defaultMasterRatio = 0.6

    -- Scroll layout state
    o.scrollColumns = {}   -- Array of columns, each column is array of window IDs
    o.scrollViewOffset = 0 -- Which column is first visible
    o.scrollMaxVisible = 3 -- Max columns visible at once

    return o
end

--------------------------------------------------------------------------------
-- Placing windows
--------------------------------------------------------------------------------

local FRAME_TOLERANCE = 1.5 -- px: windows round to whole pixels, so smaller differences are noise

--- Move/resize a window, unless it is already there. Every accessibility write costs time and makes the
--- app report a move, which would trigger another layout pass; skipping no-ops ends that loop.
function Layouts:place(win, f)
    local ok, cur = pcall(win.frame, win)
    if ok and cur
        and math.abs(cur.x - f.x) < FRAME_TOLERANCE and math.abs(cur.y - f.y) < FRAME_TOLERANCE
        and math.abs(cur.w - f.w) < FRAME_TOLERANCE and math.abs(cur.h - f.h) < FRAME_TOLERANCE then
        return
    end
    pcall(win.setFrame, win, f)
end

--- Park a window's top-left corner, unless it is already there
function Layouts:park(win, pos)
    local ok, cur = pcall(win.frame, win)
    if ok and cur and math.abs(cur.x - pos.x) < FRAME_TOLERANCE and math.abs(cur.y - pos.y) < FRAME_TOLERANCE then
        return
    end
    pcall(win.setTopLeft, win, pos)
end

--------------------------------------------------------------------------------
-- TILING LAYOUT (Unified Master/BSP replacement)
-- Default: master-stack (60/40), with manual column/row creation
--------------------------------------------------------------------------------

function Layouts:layout_tile(screen, wins)
    if #wins == 0 then
        self.tileColumns = {}
        return
    end

    local gap = self.spoon.config.gap or 8

    -- If no columns exist or structure invalid, create default master-stack
    if #self.tileColumns == 0 then
        self:tileBuildDefaultStructure(wins)
    else
        -- Sync columns with current windows (add new, remove missing)
        self:tileSyncColumns(wins)
    end

    -- If still no columns after sync, rebuild
    if #self.tileColumns == 0 then
        self:tileBuildDefaultStructure(wins)
    end

    -- Create window ID to window object map
    local winMap = {}
    for _, win in ipairs(wins) do
        local ok, id = pcall(function() return win:id() end)
        if ok and id then winMap[id] = win end
    end

    -- Calculate total ratio for normalization
    local totalRatio = 0
    for _, col in ipairs(self.tileColumns) do
        totalRatio = totalRatio + (col.ratio or 1)
    end
    if totalRatio == 0 then totalRatio = 1 end

    -- Layout columns
    local numCols = #self.tileColumns
    local totalGaps = (numCols - 1) * gap
    local availWidth = screen.w - totalGaps
    local xPos = screen.x

    for _, col in ipairs(self.tileColumns) do
        local colWidth = availWidth * (col.ratio / totalRatio)
        local numRows = #col.windows

        if numRows > 0 then
            local rowGaps = (numRows - 1) * gap
            local availHeight = screen.h - rowGaps

            -- Calculate row heights
            local rowHeights = {}
            if col.rowRatios and #col.rowRatios == numRows then
                -- Use custom row ratios
                local totalRowRatio = 0
                for _, r in ipairs(col.rowRatios) do totalRowRatio = totalRowRatio + r end
                if totalRowRatio == 0 then totalRowRatio = 1 end
                for i, r in ipairs(col.rowRatios) do
                    rowHeights[i] = availHeight * (r / totalRowRatio)
                end
            else
                -- Equal heights
                local equalHeight = availHeight / numRows
                for i = 1, numRows do rowHeights[i] = equalHeight end
            end

            -- Position windows
            local yPos = screen.y
            for rowIdx, winId in ipairs(col.windows) do
                local win = winMap[winId]
                if win then
                    self:place(win, { x = xPos, y = yPos, w = colWidth, h = rowHeights[rowIdx] })
                end
                yPos = yPos + rowHeights[rowIdx] + gap
            end
        end

        xPos = xPos + colWidth + gap
    end
end

-- Build default master-stack structure
function Layouts:tileBuildDefaultStructure(wins)
    self.tileColumns = {}
    if #wins == 0 then return end

    local masterRatio = self.defaultMasterRatio

    if #wins == 1 then
        -- Single window: fullscreen
        local ok, id = pcall(function() return wins[1]:id() end)
        if ok and id then
            table.insert(self.tileColumns, { windows = { id }, ratio = 1.0 })
        end
    else
        -- Multiple windows: master (60%) + stack (40%)
        local masterId
        local ok, id = pcall(function() return wins[1]:id() end)
        if ok and id then masterId = id end

        if masterId then
            table.insert(self.tileColumns, { windows = { masterId }, ratio = masterRatio })
        end

        -- Stack column (remaining windows)
        local stackWindows = {}
        for i = 2, #wins do
            local wok, wid = pcall(function() return wins[i]:id() end)
            if wok and wid then
                table.insert(stackWindows, wid)
            end
        end

        if #stackWindows > 0 then
            table.insert(self.tileColumns, { windows = stackWindows, ratio = 1 - masterRatio })
        end
    end
end

-- Sync columns with current windows (remove missing, add new)
function Layouts:tileSyncColumns(wins)
    -- Build set of current window IDs
    local currentWins = {}
    for _, win in ipairs(wins) do
        local ok, id = pcall(function() return win:id() end)
        if ok and id then currentWins[id] = true end
    end

    -- Remove missing windows from columns
    for colIdx = #self.tileColumns, 1, -1 do
        local col = self.tileColumns[colIdx]
        for winIdx = #col.windows, 1, -1 do
            if not currentWins[col.windows[winIdx]] then
                table.remove(col.windows, winIdx)
                -- Adjust rowRatios if present
                if col.rowRatios and #col.rowRatios >= winIdx then
                    table.remove(col.rowRatios, winIdx)
                end
            else
                -- Mark as found
                currentWins[col.windows[winIdx]] = nil
            end
        end
        -- Remove empty columns
        if #col.windows == 0 then
            table.remove(self.tileColumns, colIdx)
        end
    end

    -- Normalize row ratios for columns that lost windows
    for _, col in ipairs(self.tileColumns) do
        if col.rowRatios then
            self:tileNormalizeRowRatios(col)
        end
    end

    -- Add new windows to stack column (or create columns as needed)
    for winId, _ in pairs(currentWins) do
        if #self.tileColumns == 0 then
            -- No columns exist, create first
            table.insert(self.tileColumns, { windows = { winId }, ratio = 1.0 })
        elseif #self.tileColumns == 1 then
            -- Transitioning from 1 to 2 columns - use default 60/40 split
            self.tileColumns[1].ratio = self.defaultMasterRatio
            table.insert(self.tileColumns, { windows = { winId }, ratio = 1 - self.defaultMasterRatio })
        else
            -- Add to last column (stack behavior)
            local lastCol = self.tileColumns[#self.tileColumns]
            table.insert(lastCol.windows, winId)
            -- Clear rowRatios to trigger equal distribution
            lastCol.rowRatios = nil
        end
    end

    -- Normalize column ratios
    self:tileNormalizeColumnRatios()
end

-- Locate a window in tileColumns: returns colIdx, winIdx (or nil)
function Layouts:tileFindWindow(winId)
    for colIdx, col in ipairs(self.tileColumns) do
        for winIdx, id in ipairs(col.windows) do
            if id == winId then return colIdx, winIdx end
        end
    end
end

-- Create new column with focused window
function Layouts:tileCreateColumn(winId)
    if not winId then return false end

    -- Find and remove from current column
    local colIdx, winIdx = self:tileFindWindow(winId)
    if not colIdx then return false end

    local col = self.tileColumns[colIdx]
    table.remove(col.windows, winIdx)
    if col.rowRatios and #col.rowRatios >= winIdx then
        table.remove(col.rowRatios, winIdx)
    end
    if #col.windows == 0 then
        table.remove(self.tileColumns, colIdx) -- Remove empty column
    else
        self:tileNormalizeRowRatios(col)
    end

    -- Create new column at the end
    local numCols = #self.tileColumns
    local newRatio = 1.0 / (numCols + 1)

    -- Shrink existing columns proportionally
    for _, col in ipairs(self.tileColumns) do
        col.ratio = col.ratio * (numCols / (numCols + 1))
    end

    table.insert(self.tileColumns, { windows = { winId }, ratio = newRatio })

    return true
end

-- Move window to left column
function Layouts:tileMoveLeft(winId)
    if not winId then return false end

    local sourceColIdx, sourceWinIdx = self:tileFindWindow(winId)

    if not sourceColIdx or sourceColIdx <= 1 then return false end

    -- Remove from source
    table.remove(self.tileColumns[sourceColIdx].windows, sourceWinIdx)
    local sourceCol = self.tileColumns[sourceColIdx]
    if sourceCol.rowRatios then
        table.remove(sourceCol.rowRatios, sourceWinIdx)
        self:tileNormalizeRowRatios(sourceCol)
    end

    -- Clean up empty column
    if #self.tileColumns[sourceColIdx].windows == 0 then
        table.remove(self.tileColumns, sourceColIdx)
    end

    -- Add to left column
    local leftColIdx = sourceColIdx - 1
    if leftColIdx > #self.tileColumns then leftColIdx = #self.tileColumns end
    if leftColIdx >= 1 then
        local leftCol = self.tileColumns[leftColIdx]
        table.insert(leftCol.windows, winId)
        leftCol.rowRatios = nil -- Reset to equal heights
    end

    self:tileNormalizeColumnRatios()
    return true
end

-- Move window to right column
function Layouts:tileMoveRight(winId)
    if not winId then return false end

    local sourceColIdx, sourceWinIdx = self:tileFindWindow(winId)

    if not sourceColIdx then return false end

    -- Remove from source
    table.remove(self.tileColumns[sourceColIdx].windows, sourceWinIdx)
    local sourceCol = self.tileColumns[sourceColIdx]
    if sourceCol.rowRatios then
        table.remove(sourceCol.rowRatios, sourceWinIdx)
        self:tileNormalizeRowRatios(sourceCol)
    end

    local targetColIdx = sourceColIdx + 1

    -- Clean up empty source column
    if #self.tileColumns[sourceColIdx].windows == 0 then
        table.remove(self.tileColumns, sourceColIdx)
        targetColIdx = targetColIdx - 1
    end

    -- Add to right column or create new
    if targetColIdx <= #self.tileColumns then
        local rightCol = self.tileColumns[targetColIdx]
        table.insert(rightCol.windows, winId)
        rightCol.rowRatios = nil -- Reset to equal heights
    else
        -- Create new column at right
        table.insert(self.tileColumns, { windows = { winId }, ratio = 0.3 })
    end

    self:tileNormalizeColumnRatios()
    return true
end

-- Resize column width
function Layouts:tileResizeColumn(winId, direction)
    local colIdx = self:tileFindWindow(winId)
    if not colIdx or #self.tileColumns < 2 then return false end

    local step = (self.spoon.config.resizing and self.spoon.config.resizing.step) or 0.05
    local col = self.tileColumns[colIdx]

    if direction == "right" then
        -- Grow this column, shrink right neighbor (or left if at right edge)
        local neighborIdx = colIdx < #self.tileColumns and colIdx + 1 or colIdx - 1
        if neighborIdx >= 1 and neighborIdx <= #self.tileColumns then
            local neighbor = self.tileColumns[neighborIdx]
            if neighbor.ratio > 0.1 then
                col.ratio = col.ratio + step
                neighbor.ratio = neighbor.ratio - step
            end
        end
    elseif direction == "left" then
        -- Shrink this column, grow left neighbor (or right if at left edge)
        local neighborIdx = colIdx > 1 and colIdx - 1 or colIdx + 1
        if neighborIdx >= 1 and neighborIdx <= #self.tileColumns then
            local neighbor = self.tileColumns[neighborIdx]
            if col.ratio > 0.1 then
                col.ratio = col.ratio - step
                neighbor.ratio = neighbor.ratio + step
            end
        end
    end

    return true
end

-- Resize row height within column
function Layouts:tileResizeRow(winId, direction)
    local colIdx, winIdx = self:tileFindWindow(winId)
    local targetCol = colIdx and self.tileColumns[colIdx]
    if not targetCol or #targetCol.windows < 2 then return false end

    -- Initialize rowRatios if not present
    if not targetCol.rowRatios or #targetCol.rowRatios ~= #targetCol.windows then
        targetCol.rowRatios = {}
        local equalRatio = 1.0 / #targetCol.windows
        for i = 1, #targetCol.windows do
            targetCol.rowRatios[i] = equalRatio
        end
    end

    local step = (self.spoon.config.resizing and self.spoon.config.resizing.step) or 0.05

    if direction == "down" then
        -- Grow this row, shrink row below (or above if at bottom)
        local neighborIdx = winIdx < #targetCol.windows and winIdx + 1 or winIdx - 1
        if targetCol.rowRatios[neighborIdx] > 0.1 then
            targetCol.rowRatios[winIdx] = targetCol.rowRatios[winIdx] + step
            targetCol.rowRatios[neighborIdx] = targetCol.rowRatios[neighborIdx] - step
        end
    elseif direction == "up" then
        -- Shrink this row, grow row above (or below if at top)
        local neighborIdx = winIdx > 1 and winIdx - 1 or winIdx + 1
        if targetCol.rowRatios[winIdx] > 0.1 then
            targetCol.rowRatios[winIdx] = targetCol.rowRatios[winIdx] - step
            targetCol.rowRatios[neighborIdx] = targetCol.rowRatios[neighborIdx] + step
        end
    end

    return true
end

-- Normalize column ratios to sum to 1.0
function Layouts:tileNormalizeColumnRatios()
    if #self.tileColumns == 0 then return end
    local total = 0
    for _, col in ipairs(self.tileColumns) do
        total = total + (col.ratio or 1)
    end
    if total == 0 then total = 1 end
    for _, col in ipairs(self.tileColumns) do
        col.ratio = (col.ratio or 1) / total
    end
end

-- Normalize row ratios to sum to 1.0
function Layouts:tileNormalizeRowRatios(col)
    if not col.rowRatios or #col.rowRatios == 0 then return end
    -- Adjust array length to match windows
    while #col.rowRatios > #col.windows do
        table.remove(col.rowRatios)
    end
    while #col.rowRatios < #col.windows do
        table.insert(col.rowRatios, 1.0 / #col.windows)
    end
    -- Normalize
    local total = 0
    for _, r in ipairs(col.rowRatios) do total = total + r end
    if total == 0 then total = 1 end
    for i, r in ipairs(col.rowRatios) do
        col.rowRatios[i] = r / total
    end
end

-- Balance tiling layout (reset to default 60/40)
function Layouts:tileBalance()
    if #self.tileColumns == 0 then return end

    if #self.tileColumns == 1 then
        self.tileColumns[1].ratio = 1.0
    elseif #self.tileColumns == 2 then
        self.tileColumns[1].ratio = self.defaultMasterRatio
        self.tileColumns[2].ratio = 1 - self.defaultMasterRatio
    else
        -- Equal columns for 3+
        local equalRatio = 1.0 / #self.tileColumns
        for _, col in ipairs(self.tileColumns) do
            col.ratio = equalRatio
        end
    end

    -- Reset all row ratios to equal
    for _, col in ipairs(self.tileColumns) do
        col.rowRatios = nil
    end
end

-- Scroll layout: scrollable horizontal columns with center focus
-- Shows max 3 columns: side columns are smaller, center is larger
function Layouts:layout_scroll(screen, wins)
    if #wins == 0 then
        self.scrollColumns = {}
        return
    end

    local gap = self.spoon.config.gap or 8

    -- Build column structure from windows
    local windowToColumn = {}
    local columns = {}

    -- Check if we have stored column assignments
    if #self.scrollColumns > 0 then
        local winSet = {}
        for _, win in ipairs(wins) do winSet[win:id()] = win end

        for colIdx, col in ipairs(self.scrollColumns) do
            local newCol = {}
            for _, winId in ipairs(col) do
                if winSet[winId] then
                    table.insert(newCol, winId)
                    windowToColumn[winId] = colIdx
                end
            end
            if #newCol > 0 then
                table.insert(columns, newCol)
            end
        end

        for _, win in ipairs(wins) do
            local winId = win:id()
            if not windowToColumn[winId] then
                table.insert(columns, { winId })
                windowToColumn[winId] = #columns
            end
        end
    else
        for _, win in ipairs(wins) do
            local winId = win:id()
            table.insert(columns, { winId })
            windowToColumn[winId] = #columns
        end
    end

    self.scrollColumns = columns

    local numColumns = #columns
    if numColumns == 0 then return end

    -- Create window ID to window object map
    local winMap = {}
    for _, win in ipairs(wins) do winMap[win:id()] = win end

    -- Calculate visible columns and their sizes
    -- Layout: [small] [BIG CENTER] [small] with max 3 visible
    local maxOffset = math.max(0, numColumns - 1) -- Center can be any column
    self.scrollViewOffset = math.min(self.scrollViewOffset, maxOffset)

    local centerIdx = self.scrollViewOffset + 1 -- The focused/center column

    -- Determine which columns are visible
    local visibleCols = {}
    local hasLeft = centerIdx > 1
    local hasRight = centerIdx < numColumns

    if hasLeft then table.insert(visibleCols, { idx = centerIdx - 1, pos = "left" }) end
    table.insert(visibleCols, { idx = centerIdx, pos = "center" })
    if hasRight then table.insert(visibleCols, { idx = centerIdx + 1, pos = "right" }) end

    -- Calculate widths: side columns are 20% each, center is 60% (or adjust based on count)
    local sideRatio = 0.20   -- 20% for each side column
    local centerRatio = 0.60 -- 60% for center column
    local totalGaps = (#visibleCols - 1) * gap
    local availWidth = screen.w - totalGaps

    local function getColWidth(pos, visCount)
        if visCount == 1 then return availWidth end
        if visCount == 2 then
            if pos == "center" then return availWidth * 0.6 end
            return availWidth * 0.4
        end
        -- 3 columns
        if pos == "center" then return availWidth * centerRatio end
        return availWidth * sideRatio
    end

    -- Calculate positions and layout visible columns
    local xPos = screen.x
    for _, colInfo in ipairs(visibleCols) do
        local col = columns[colInfo.idx]
        local colWidth = getColWidth(colInfo.pos, #visibleCols)

        -- Stack windows vertically in column
        local windowCount = #col
        local windowHeight = (screen.h - gap * (windowCount - 1)) / windowCount

        for winIdx, winId in ipairs(col) do
            local win = winMap[winId]
            if win then
                local frame = {
                    x = xPos,
                    y = screen.y + (winIdx - 1) * (windowHeight + gap),
                    w = colWidth,
                    h = windowHeight
                }
                self:place(win, frame)
            end
        end

        xPos = xPos + colWidth + gap
    end

    -- Raise windows in center column to ensure proper z-order
    for _, colInfo in ipairs(visibleCols) do
        if colInfo.pos == "center" then
            local col = columns[colInfo.idx]
            for _, winId in ipairs(col) do
                local win = winMap[winId]
                if win then
                    pcall(function() win:raise() end)
                end
            end
        end
    end

    -- Hide windows in non-visible columns (bottom-right, like tag hiding)
    local visibleSet = {}
    for _, colInfo in ipairs(visibleCols) do visibleSet[colInfo.idx] = true end

    local mainScreen = hs.screen.mainScreen():frame()
    local offScreenPos = {
        x = mainScreen.x + mainScreen.w - 5,
        y = mainScreen.y + mainScreen.h - 5
    }

    for colIdx = 1, numColumns do
        if not visibleSet[colIdx] then
            local col = columns[colIdx]
            for _, winId in ipairs(col) do
                local win = winMap[winId]
                if win then
                    self:park(win, offScreenPos)
                end
            end
        end
    end
end

-- Index of the scroll column containing winId (or nil)
function Layouts:scrollFindWindow(winId)
    for colIdx, col in ipairs(self.scrollColumns or {}) do
        for _, id in ipairs(col) do
            if id == winId then return colIdx end
        end
    end
end

-- Scroll left (move center focus to previous column)
function Layouts:scrollLeft()
    if self.scrollViewOffset > 0 then
        self.scrollViewOffset = self.scrollViewOffset - 1
        return true
    end
    return false
end

-- Scroll right (move center focus to next column)
function Layouts:scrollRight()
    local maxOffset = math.max(0, #self.scrollColumns - 1)
    if self.scrollViewOffset < maxOffset then
        self.scrollViewOffset = self.scrollViewOffset + 1
        return true
    end
    return false
end

-- Move focused window to left column
function Layouts:scrollMoveLeft(winId)
    if not winId then return false end

    -- Find current column
    local currentCol = nil
    local currentIdx = nil
    for colIdx, col in ipairs(self.scrollColumns) do
        for winIdx, id in ipairs(col) do
            if id == winId then
                currentCol = colIdx
                currentIdx = winIdx
                break
            end
        end
        if currentCol then break end
    end

    if not currentCol then return false end

    -- Remove from current column
    table.remove(self.scrollColumns[currentCol], currentIdx)

    -- If column is now empty, remove it
    if #self.scrollColumns[currentCol] == 0 then
        table.remove(self.scrollColumns, currentCol)
        currentCol = currentCol - 1
    end

    -- Add to left column or create new column
    if currentCol <= 0 then
        -- Create new column at start
        table.insert(self.scrollColumns, 1, { winId })
    else
        -- Add to existing left column
        table.insert(self.scrollColumns[currentCol], winId)
    end

    return true
end

-- Move focused window to right column
function Layouts:scrollMoveRight(winId)
    if not winId then return false end

    -- Find current column
    local currentCol = nil
    local currentIdx = nil
    for colIdx, col in ipairs(self.scrollColumns) do
        for winIdx, id in ipairs(col) do
            if id == winId then
                currentCol = colIdx
                currentIdx = winIdx
                break
            end
        end
        if currentCol then break end
    end

    if not currentCol then return false end

    -- Remove from current column
    table.remove(self.scrollColumns[currentCol], currentIdx)

    local targetCol = currentCol + 1

    -- If column is now empty, remove it
    if #self.scrollColumns[currentCol] == 0 then
        table.remove(self.scrollColumns, currentCol)
        targetCol = targetCol - 1
    end

    -- Add to right column or create new column
    if targetCol > #self.scrollColumns then
        -- Create new column at end
        table.insert(self.scrollColumns, { winId })
    else
        -- Add to existing right column
        table.insert(self.scrollColumns[targetCol], winId)
    end

    return true
end

-- Create new column with focused window
function Layouts:scrollCreateColumn(winId)
    if not winId then return false end

    -- Find and remove from current column
    for colIdx, col in ipairs(self.scrollColumns) do
        for winIdx, id in ipairs(col) do
            if id == winId then
                table.remove(self.scrollColumns[colIdx], winIdx)
                if #self.scrollColumns[colIdx] == 0 then
                    table.remove(self.scrollColumns, colIdx)
                end
                break
            end
        end
    end

    -- Create new column at end
    table.insert(self.scrollColumns, { winId })

    -- Scroll to show the new column
    local maxOffset = math.max(0, #self.scrollColumns - self.scrollMaxVisible)
    self.scrollViewOffset = maxOffset

    return true
end

--------------------------------------------------------------------------------
-- STACKING LAYOUT
-- All windows superimposed with only 1px visible at bottom-right
--------------------------------------------------------------------------------

function Layouts:layout_stack(screen, wins)
    if #wins == 0 then return end

    -- The first window gets the whole screen; the others wait behind it, parked at the bottom-right
    -- corner (AeroSpace-style), each 1px lower so they stay distinct. Focus is never changed here:
    -- whoever reorders the stack (rotation, tag switch) decides what gets focus.
    local top = wins[1]
    self:place(top, { x = screen.x, y = screen.y, w = screen.w, h = screen.h })
    pcall(top.raise, top)

    for i = 2, #wins do
        self:park(wins[i], { x = screen.x + screen.w - 1, y = screen.y + screen.h - 1 + (i - 2) })
    end
end

return Layouts
