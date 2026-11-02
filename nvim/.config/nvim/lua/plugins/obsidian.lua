-- Obsidian vaults: [[wiki links]], backlinks, tags, daily notes, templates, note search.
-- The plugin only activates for notes inside a vault; Markdown outside one is plain Markdown and is
-- rendered by render-markdown.nvim. Inside a vault: <CR> follows the link, toggles the checkbox or lists
-- the tag under the cursor, and ]o / [o jump between links.
--
-- A vault is any folder that contains a `.obsidian` directory, found one level below these roots.
-- Add the roots you keep vaults in; add a vault outside them to `vaults` directly.
local roots = {
    "~/Documents",
    "~/Notes",
    "~/Library/Mobile Documents/iCloud~md~obsidian/Documents", -- the Obsidian iCloud folder
}
local vaults = {}

local workspaces = {}
local seen = {}

local function add(path)
    path = vim.fs.normalize(path)
    if not seen[path] and vim.uv.fs_stat(path .. "/.obsidian") then
        seen[path] = true
        table.insert(workspaces, { name = vim.fs.basename(path), path = path })
    end
end

for _, root in ipairs(roots) do
    root = vim.fs.normalize(root)
    for name, type in vim.fs.dir(root) do
        if type == "directory" then
            add(root .. "/" .. name)
        end
    end
end
for _, vault in ipairs(vaults) do
    add(vault)
end

-- No vault on this machine: render-markdown still works, and nothing here is loaded
if #workspaces == 0 then
    return
end

vim.pack.add({
    { src = "https://github.com/obsidian-nvim/obsidian.nvim", version = vim.version.range("*") },
})

require("obsidian").setup({
    legacy_commands = false, -- only `:Obsidian <subcommand>`
    workspaces = workspaces,
    picker = { name = "telescope.nvim" },
    -- render-markdown draws the checkboxes, bullets and links; two renderers on one buffer clash
    ui = { enable = false },
})

local function map(lhs, cmd, desc, mode)
    vim.keymap.set(mode or "n", lhs, "<cmd>Obsidian " .. cmd .. "<cr>", { desc = desc })
end

map("<leader>oo", "quick_switch", "Open a note")
map("<leader>on", "new", "New note")
map("<leader>os", "search", "Search the vault")
map("<leader>ot", "tags", "Find notes by tag")
map("<leader>od", "today", "Today's daily note")
map("<leader>oD", "dailies", "Pick a daily note")
map("<leader>ob", "backlinks", "Backlinks of this note")
map("<leader>ol", "links", "Links in this note")
map("<leader>oc", "toc", "Table of contents")
map("<leader>or", "rename", "Rename note and update links")
map("<leader>ow", "workspace", "Switch vault")
