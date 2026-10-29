-- Formatters are external tools and must be installed separately:
--   stylua: `brew install stylua`
--   ruff:   `uv tool install ruff`
--   prettier (Markdown): `brew install prettier`
--   zigfmt (Zig): part of zig, `brew install zig`
-- `:ConformInfo` shows which formatters are available for the current buffer.
vim.pack.add({
    "https://github.com/stevearc/conform.nvim",
})

local conform = require("conform")

conform.setup({
    formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_organize_imports", "ruff_format" },
        markdown = { "prettier" },
        zig = { "zigfmt" },
    },
    -- Filetypes without a formatter above fall back to the language server, if it can format
    format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
})

-- Conform skips a missing formatter silently, so say so at startup
local missing, seen = {}, {}
for _, formatters in pairs(conform.formatters_by_ft) do
    for _, name in ipairs(formatters) do
        if not seen[name] and not conform.get_formatter_info(name).available then
            table.insert(missing, name)
        end
        seen[name] = true
    end
end
if #missing > 0 then
    table.sort(missing)
    vim.schedule(function()
        vim.notify("Formatter not installed, skipped: " .. table.concat(missing, ", "), vim.log.levels.WARN)
    end)
end

vim.keymap.set({ "n", "v" }, "<leader>cf", function()
    conform.format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer or selection" })
