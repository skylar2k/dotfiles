-- Not lazy-loaded: oil must be active at startup to take over directory buffers (`nvim .`)
vim.pack.add({
    "https://github.com/stevearc/oil.nvim",
})

local oil = require("oil")
local project = require("util.project")

-- Keys below are buffer-local with a `desc`; which-key lists them as you type a prefix (e.g. `g`).
-- `h`/`l` replace the character motions in oil buffers: use 0, $, w and b to move within a name.
oil.setup({
    default_file_explorer = true,
    columns = { "icon" },
    watch_for_changes = true, -- reload when files change outside oil
    win_options = {
        winbar = "%!v:lua.require('util.project').winbar()",
    },
    view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
            return name == ".." or name == ".git"
        end,
    },
    keymaps = {
        -- Frees <C-s>/<C-h>; splits use Telescope's keys instead
        ["<C-s>"] = false,
        ["<C-h>"] = false,
        ["<C-v>"] = { "actions.select", opts = { vertical = true }, desc = "Open in vertical split" },
        ["<C-x>"] = { "actions.select", opts = { horizontal = true }, desc = "Open in horizontal split" },

        -- Nordic layout: ~, ` and \ are dead keys or need AltGr, so oil's defaults for them
        -- (`~`-style home, `` ` ``, g~, g\) are replaced with letter keys.
        ["`"] = false,
        ["g~"] = false,
        ["g\\"] = false,

        -- Navigation (`-` for parent and `_` for cwd are oil defaults)
        ["h"] = { "actions.parent", mode = "n" },
        ["l"] = "actions.select",
        ["q"] = { "actions.close", mode = "n" },
        ["gh"] = {
            callback = function()
                oil.open(vim.fn.expand("~"))
            end,
            desc = "Open home directory",
        },
        ["gp"] = { callback = project.open_root, desc = "Open project root" },

        -- Working directory
        ["gd"] = { "actions.cd", mode = "n", desc = "Set cwd to this directory" },
        ["gD"] = { "actions.cd", opts = { scope = "tab" }, mode = "n", desc = "Set tab-local cwd to this directory" },
        ["gR"] = { callback = project.set_root, desc = "Set cwd to project root" },

        ["gX"] = { "actions.toggle_trash", mode = "n" },

        ["gy"] = "actions.copy_entry_path",
        ["gq"] = "actions.send_to_qflist",
    },
})

-- Pass the directory explicitly: with no argument oil opens the *parent* of the current buffer,
-- which from inside an oil buffer means going up a level (use `-` for that).
vim.keymap.set("n", "<leader>fb", function()
    oil.toggle_float(project.dir())
end, { desc = "File browser (oil float)" })
vim.keymap.set("n", "<leader>f-", function()
    oil.open(project.dir())
end, { desc = "Oil: this file's directory" })
vim.keymap.set("n", "<leader>fe", function()
    oil.open(vim.fn.getcwd())
end, { desc = "Oil: working directory" })
vim.keymap.set("n", "<leader>fr", project.open_root, { desc = "Oil: project root" })
