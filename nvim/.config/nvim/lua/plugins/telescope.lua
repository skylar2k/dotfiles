-- telescope-fzf-native is built by the PackChanged hook in config/plugins.lua
vim.pack.add({
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/nvim-telescope/telescope.nvim",
    "https://github.com/nvim-telescope/telescope-fzf-native.nvim",
})

require('telescope').setup {
    defaults = {
        -- Search hidden files, but never the contents of .git/
        file_ignore_patterns = { "^%.git/" },
        vimgrep_arguments = {
            "rg", "--color=never", "--no-heading", "--with-filename",
            "--line-number", "--column", "--smart-case", "--hidden",
        },
    },
    pickers = {
        find_files = { hidden = true },
    },
    extensions = {
        fzf = {
            fuzzy = true,                   -- false will only do exact matching
            override_generic_sorter = true, -- override the generic sorter
            override_file_sorter = true,    -- override the file sorter
            case_mode = "smart_case",       -- or "ignore_case" or "respect_case"
            -- the default case_mode is "smart_case"
        }
    }
}

-- Warn instead of erroring if the build is missing, so startup isn't blocked
local ok, err = pcall(require("telescope").load_extension, "fzf")
if not ok then
    vim.notify("telescope-fzf-native not loaded (missing build?):\n" .. err, vim.log.levels.WARN)
end

local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fc", function()
    builtin.find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Find neovim config files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>bb", builtin.buffers, { desc = "Search buffers" })
vim.keymap.set("n", "<leader>?", builtin.help_tags, { desc = "Help tags" })
