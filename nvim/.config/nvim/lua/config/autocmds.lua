local group = vim.api.nvim_create_augroup("config.autocmds", { clear = true })

-- Flash yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
    group = group,
    callback = function()
        vim.hl.on_yank()
    end,
})

-- Reopen files at the last cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
        if vim.bo[ev.buf].filetype:match("commit") then
            return
        end
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- Keep splits equal when the terminal is resized
vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    command = "wincmd =",
})
