-- Plugins are managed by the built-in vim.pack (Neovim 0.12+).
-- Each file in lua/plugins/ is self-contained: it add()s its plugin(s) and configures them.
-- Files load in alphabetical order; prefix a name (e.g. 00-colorscheme.lua) to load it earlier.
-- Update with `:lua vim.pack.update()`, review the diff, `:write` to confirm.
-- Revisions are pinned in nvim-pack-lock.json; commit it.

-- Build steps run after a plugin is installed or updated: name -> command (list) or function(path).
-- They live here, not in lua/plugins/, because vim.pack installs everything in the lockfile on the
-- first add() call, so the PackChanged hook must exist before any plugin file runs.
local builds = {
    ["telescope-fzf-native.nvim"] = { "make" },
}

vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(ev)
        local data = ev.data
        local build = builds[data.spec.name]
        if not build or (data.kind ~= "install" and data.kind ~= "update") then
            return
        end
        if type(build) == "function" then
            build(data.path)
            return
        end
        local result = vim.system(build, { cwd = data.path }):wait()
        if result.code ~= 0 then
            vim.notify(data.spec.name .. " build failed:\n" .. result.stderr, vim.log.levels.ERROR)
        end
    end,
})

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
