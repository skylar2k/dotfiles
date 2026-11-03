-- Zen mode: the current buffer in a centred column, with the line numbers, sign column, statusline and
-- command line hidden. <leader>z toggles it; closing the window or running :ZenMode again leaves it.
return {
    profile = "full",
    src = {
        "https://github.com/folke/zen-mode.nvim",
    },
    setup = function()
        require("zen-mode").setup({
            window = {
                backdrop = 1, -- no dimmed backdrop: the colorscheme's own background fills the screen
                width = 100,
                options = {
                    number = false,
                    relativenumber = false,
                    signcolumn = "no",
                    cursorline = false,
                    foldcolumn = "0",
                    list = false,
                },
            },
            plugins = {
                options = { enabled = true, ruler = false, showcmd = false, laststatus = 0 },
            },
        })

        vim.keymap.set("n", "<leader>z", "<cmd>ZenMode<cr>", { desc = "Zen mode" })
    end,
}
