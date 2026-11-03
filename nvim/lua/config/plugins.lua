-- Plugins are managed by the built-in vim.pack (Neovim 0.12+).
-- Each file in lua/plugins/ returns a spec:
--   profile  "lite" (everywhere) or "full" (workstations only)
--   requires executables the plugin needs; it is skipped when one is missing
--   skip     optional reason to skip it on this machine (e.g. no Obsidian vault)
--   src      what to vim.pack.add(): URLs or vim.pack specs
--   setup    configuration and keymaps, run after every plugin is added
-- Files load in alphabetical order; prefix a name (e.g. 00-colorscheme.lua) to load it earlier.
-- The profile comes from $NVIM_PROFILE: "full" (default) or "lite" (servers, shared accounts).
-- Update with `:PackUpdate` (defined at the bottom), review the changelog, `:write` to confirm.
-- Revisions are pinned in nvim-pack-lock.json; commit it.
local M = {}

M.profile = vim.env.NVIM_PROFILE or "full"
if M.profile ~= "full" and M.profile ~= "lite" then
    vim.notify(("NVIM_PROFILE=%s is not full or lite, using full"):format(M.profile), vim.log.levels.WARN)
    M.profile = "full"
end

if not vim.pack then
    vim.schedule(function()
        vim.notify(("Neovim %s has no vim.pack (needs 0.12): plugins skipped"):format(vim.version()), vim.log.levels.INFO)
    end)
    return M
end

-- Build steps run after a plugin is installed or updated: name -> command (list) or function(path).
-- They live here, not in lua/plugins/, because vim.pack installs everything in the lockfile on the
-- first add() call, so the PackChanged hook must exist before any plugin is added.
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

-- The directory name vim.pack gives a plugin
local function pack_name(src)
    if type(src) == "table" then
        return src.name or pack_name(src.src)
    end
    return (src:gsub("%.git$", ""):match("[^/]+$"))
end

local function skip_reason(spec)
    if spec.profile ~= "lite" and M.profile ~= "full" then
        return "full only"
    end
    local missing = vim.tbl_filter(function(exe)
        return vim.fn.executable(exe) == 0
    end, spec.requires or {})
    if #missing > 0 then
        return "no " .. table.concat(missing, ", ")
    end
    return spec.skip
end

local dir = vim.fn.stdpath("config") .. "/lua/plugins"

local modules = {}
for name, type in vim.fs.dir(dir) do
    if type == "file" and name:match("%.lua$") then
        table.insert(modules, (name:gsub("%.lua$", "")))
    end
end
table.sort(modules)

local active, skipped, srcs, wanted = {}, {}, {}, {}
for _, module in ipairs(modules) do
    local ok, spec = pcall(require, "plugins." .. module)
    if not ok then
        vim.notify("plugins." .. module .. ": " .. spec, vim.log.levels.ERROR)
    else
        local reason = skip_reason(spec)
        if reason then
            table.insert(skipped, ("%s (%s)"):format(module, reason))
        else
            spec.module = module
            table.insert(active, spec)
            for _, src in ipairs(spec.src or {}) do
                table.insert(srcs, src)
                wanted[pack_name(src)] = true
            end
        end
    end
end

-- vim.pack installs every plugin in the lockfile that is not on disk on the first add(), so it is not
-- shown the entries of skipped plugins it would download: lite never downloads full-only plugins.
-- (Plugins already on disk keep their entry, or vim.pack would "repair" it.) vim.pack then writes the
-- lockfile without the hidden entries (and without any plugin whose clone failed); they are put back.
local lock_path = vim.fs.joinpath(vim.fn.stdpath("config"), "nvim-pack-lock.json")
local pack_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt")

local function lock_read()
    local file = io.open(lock_path, "r")
    if not file then
        return nil
    end
    local ok, lock = pcall(vim.json.decode, file:read("*a"))
    file:close()
    return ok and type(lock) == "table" and type(lock.plugins) == "table" and lock or nil
end

local lock = lock_read()
local hidden = {}
if lock then
    for name, data in pairs(lock.plugins) do
        if not wanted[name] and not vim.uv.fs_stat(vim.fs.joinpath(pack_dir, name)) then
            hidden[name] = data
        end
    end
end

local decode = vim.json.decode
vim.json.decode = function(...)
    local data = decode(...)
    if type(data) == "table" and type(data.plugins) == "table" then
        for name in pairs(hidden) do
            data.plugins[name] = nil
        end
    end
    return data
end
local ok, err = pcall(vim.pack.add, srcs)
vim.json.decode = decode
if not ok then -- usually a clone that failed (no network); the plugins that did install still load
    vim.notify(err, vim.log.levels.WARN)
end

local loaded = {}
for _, plugin in ipairs(vim.pack.get(nil, { info = false })) do
    loaded[plugin.spec.name] = plugin.active
end

-- Plugins in the lockfile that failed to install (no network) keep their entry too
for name in pairs(wanted) do
    if not loaded[name] and lock and lock.plugins[name] then
        hidden[name] = lock.plugins[name]
    end
end

-- Same format as vim.pack's own lockfile writes, so `git diff` stays empty
local function lock_restore()
    local current = lock_read()
    if not current then
        return
    end
    local changed = false
    for name, data in pairs(hidden) do
        if current.plugins[name] == nil then
            current.plugins[name] = data
            changed = true
        end
    end
    if changed then
        local file = assert(io.open(lock_path, "w"))
        file:write(vim.json.encode(current, { indent = "  ", sort_keys = true }) .. "\n")
        file:close()
    end
end

if next(hidden) then
    lock_restore()
    -- vim.pack.update() and friends rewrite the lockfile from what this session added
    vim.api.nvim_create_autocmd("VimLeavePre", { callback = lock_restore })
end

for _, spec in ipairs(active) do
    local missing = vim.tbl_filter(function(src)
        return not loaded[pack_name(src)]
    end, spec.src or {})
    if #missing > 0 then
        table.insert(skipped, ("%s (not installed: %s)"):format(spec.module, table.concat(vim.tbl_map(pack_name, missing), ", ")))
    elseif spec.setup then
        local setup_ok, setup_err = pcall(spec.setup)
        if not setup_ok then
            vim.notify("plugins." .. spec.module .. ": " .. setup_err, vim.log.levels.ERROR)
        end
    end
end

-- :PackUpdate [plugin...]   fetch new commits and open the review buffer; `:write` there applies them
-- :PackUpdate! [plugin...]  move plugins back to the commits in nvim-pack-lock.json, without asking
-- Only plugins installed on this machine are updated; the lockfile keeps the entries of the others.
vim.api.nvim_create_user_command("PackUpdate", function(cmd)
    local names = #cmd.fargs > 0 and cmd.fargs or nil
    vim.pack.update(names, cmd.bang and { target = "lockfile", force = true } or {})
end, {
    bang = true,
    nargs = "*",
    desc = "Update plugins (! resets them to the lockfile)",
    complete = function(arglead)
        local names = vim.tbl_map(function(plugin)
            return plugin.spec.name
        end, vim.pack.get(nil, { info = false }))
        return vim.tbl_filter(function(name)
            return vim.startswith(name, arglead)
        end, names)
    end,
})

if #skipped > 0 then
    vim.schedule(function()
        vim.notify(("Plugins skipped (%s profile): %s"):format(M.profile, table.concat(skipped, ", ")), vim.log.levels.INFO)
    end)
end

return M
