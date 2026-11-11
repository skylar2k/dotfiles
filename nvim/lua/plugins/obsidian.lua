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

return {
    profile = "full",
    -- No vault on this machine: render-markdown still works, and nothing here is loaded
    skip = #workspaces == 0 and "no vault" or nil,
    src = {
        { src = "https://github.com/obsidian-nvim/obsidian.nvim", version = vim.version.range("*") },
    },
    setup = function()
        local function cmd(name)
            return "<cmd>Obsidian " .. name .. "<cr>"
        end

        -- The vault layout (see "How this vault works" in the vault): a flat vault where the file name is the
        -- title, templates in templates/, daily notes in daily/, attachments in attachments/.
        require("obsidian").setup({
            legacy_commands = false, -- only `:Obsidian <subcommand>`
            workspaces = workspaces,
            picker = { name = "telescope.nvim" },
            -- render-markdown draws the checkboxes, bullets and links; two renderers on one buffer clash
            ui = { enable = false },

            new_notes_location = "notes_subdir", -- no notes_subdir: the vault root
            -- File name = title, without the characters that break file names or wiki links; a note without a
            -- title (a quick capture) gets a timestamp ID
            note_id_func = function(title)
                if title ~= nil and title ~= "" then
                    return (title:gsub('[/\\:*?"<>|#^%[%]]', ""))
                end
                return require("obsidian.builtin").zettel_id()
            end,
            note = { template = "note.md" }, -- for :Obsidian new
            templates = { folder = "templates", date_format = "YYYY-MM-DD", time_format = "HH:mm" },
            unique_note = { enabled = true, format = "YYYYMMDDHHmm", template = "capture.md" }, -- quick capture
            daily_notes = {
                enabled = true,
                folder = "daily",
                date_format = "YYYY-MM-DD",
                template = "daily.md",
                default_tags = { "daily" },
                workdays_only = false,
            },
            attachments = { folder = "attachments" }, -- for :Obsidian paste_img (needs pngpaste on macOS)
            -- Update links without asking when a note is renamed outside Neovim
            link = { style = "wiki", format = "shortest", auto_update = true },
            -- An index for faster quick_switch and completion, and for link suggestions. Kept in Neovim's cache
            -- folder, not in the vault.
            cache = { enabled = true },
            frontmatter = { sort = { "id", "aliases", "tags", "type", "created" } },

            callbacks = {
                -- Keys that only exist inside notes. The language server adds Neovim's own: gf follows a link,
                -- grr lists backlinks, grn renames the note and its links, gra offers actions, gO lists headings.
                enter_note = function()
                    local function map(lhs, rhs, desc)
                        vim.keymap.set("n", lhs, rhs, { buffer = true, desc = desc })
                    end
                    local actions = require("obsidian.actions")
                    map("<leader>ob", cmd("backlinks"), "Backlinks of this note")
                    map("<leader>ol", cmd("links"), "Links in this note")
                    map("<leader>oT", cmd("template"), "Insert a template")
                    map("<leader>oa", actions.add_tag, "Add a tag")
                    map("<leader>oL", actions.link_suggestions, "Unlinked mentions")
                end,
            },
        })

        local function map(lhs, name, desc)
            vim.keymap.set("n", lhs, cmd(name), { desc = desc })
        end

        map("<leader>oo", "quick_switch", "Open a note")
        map("<leader>os", "search", "Search the vault")
        map("<leader>on", "new_from_template", "New note from a template")
        map("<leader>oc", "unique_note", "Quick capture")
        map("<leader>od", "today", "Today's daily note")
        map("<leader>oD", "dailies", "Pick a daily note")
        map("<leader>ot", "tags", "Find notes by tag")
        map("<leader>op", "properties", "Find notes by property")
        map("<leader>oi", "tags inbox", "Inbox")
        map("<leader>or", "rename", "Rename note and update links")
        map("<leader>ow", "workspace", "Switch vault")
    end,
}
