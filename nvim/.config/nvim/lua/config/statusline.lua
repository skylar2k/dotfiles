-- Statusline: mode, git branch, file, then diagnostics, LSP clients, filetype and position.
-- Redrawn by Neovim whenever it needs to, so keep render() cheap.
local M = {}

local mode_names = {
    n = "NORMAL", i = "INSERT", v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK",
    s = "SELECT", S = "S-LINE", ["\19"] = "S-BLOCK",
    R = "REPLACE", c = "COMMAND", t = "TERMINAL",
}
local mode_hl = {
    n = "StlNormal", i = "StlInsert", t = "StlInsert",
    v = "StlVisual", V = "StlVisual", ["\22"] = "StlVisual", s = "StlVisual", S = "StlVisual", ["\19"] = "StlVisual",
    R = "StlReplace", c = "StlCommand",
}

-- Mode pills take their colour from the colorscheme's own groups
local function define_highlights()
    local function fg_of(group)
        return vim.api.nvim_get_hl(0, { name = group, link = false }).fg
    end
    local pills = {
        StlNormal = "Function", StlInsert = "String", StlVisual = "Statement",
        StlReplace = "DiagnosticError", StlCommand = "Constant",
    }
    for name, source in pairs(pills) do
        vim.api.nvim_set_hl(0, name, { fg = fg_of(source), bold = true, reverse = true })
    end
end

function M.render()
    local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local active = win == vim.api.nvim_get_current_win()

    local parts = {}
    if active then
        local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
        table.insert(parts, ("%%#%s# %s %%*"):format(mode_hl[mode] or "StlNormal", mode_names[mode] or mode))
    end

    local branch = vim.b[buf].gitsigns_head -- set by gitsigns.nvim
    if branch and branch ~= "" then
        table.insert(parts, " ⎇ " .. branch:gsub("%%", "%%%%"))
    end

    table.insert(parts, " %f %m%r") -- name, modified and read-only flags
    table.insert(parts, "%=")

    if active and vim.ui.progress_status then
        table.insert(parts, vim.ui.progress_status() .. " ")
    end
    local diagnostics = vim.diagnostic.status(buf)
    if diagnostics ~= "" then
        table.insert(parts, diagnostics .. " ")
    end

    local names = {}
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
        table.insert(names, client.name)
    end
    if #names > 0 then
        table.insert(parts, table.concat(names, ",") .. " ")
    end

    local ft = vim.bo[buf].filetype
    if ft ~= "" then
        table.insert(parts, ft .. " ")
    end
    table.insert(parts, "%l:%c %P ")
    return table.concat(parts)
end

define_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("config.statusline", {}),
    callback = define_highlights,
})
vim.o.statusline = "%!v:lua.require'config.statusline'.render()"

return M
