-- Not lazy-loaded: oil must be active at startup to take over directory buffers (`nvim .`)
vim.pack.add({
    "https://github.com/stevearc/oil.nvim",
})

require("oil").setup({
    default_file_explorer = true,
    columns = { "icon" },
    view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
            return name == ".." or name == ".git"
        end,
    },
})

vim.keymap.set("n", "<leader>f-", "<cmd>Oil<CR>", { desc = "Open parent directory" })
vim.keymap.set("n", "<leader>fb", require("oil").toggle_float, { desc = "File browser (oil)" })
