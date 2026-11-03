local M = {}

-- Delete the current buffer but keep the window layout.
-- Refuses a modified buffer unless `force` is set.
function M.delete(force)
    local buf = vim.api.nvim_get_current_buf()
    if not force and vim.bo[buf].modified then
        vim.notify("Buffer has unsaved changes (use <leader>bD to discard)", vim.log.levels.WARN)
        return
    end
    -- Show another buffer in every window first so the splits survive
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        vim.api.nvim_win_call(win, function()
            pcall(vim.cmd, "bprevious")
            if vim.api.nvim_get_current_buf() == buf then
                vim.cmd("enew")
            end
        end)
    end
    vim.cmd((force and "bdelete! " or "bdelete ") .. buf)
end

return M
