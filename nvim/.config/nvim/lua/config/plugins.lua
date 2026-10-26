-- Plugins are managed by the built-in vim.pack (Neovim 0.12+).
-- Each file in lua/plugins/ is self-contained: it add()s its plugin(s) and configures them.
-- Files load in alphabetical order; prefix a name (e.g. 00-colorscheme.lua) to load it earlier.
-- Update with `:lua vim.pack.update()`, review the diff, `:write` to confirm.
-- Revisions are pinned in nvim-pack-lock.json; commit it.
local dir = vim.fn.stdpath("config") .. "/lua/plugins"

local modules = {}
for name, type in vim.fs.dir(dir) do
    if type == "file" and name:match("%.lua$") then
        table.insert(modules, (name:gsub("%.lua$", "")))
    end
end
table.sort(modules)

for _, module in ipairs(modules) do
    local ok, err = pcall(require, "plugins." .. module)
    if not ok then
        vim.notify("plugins." .. module .. ": " .. err, vim.log.levels.ERROR)
    end
end
