return {
    profile = "lite",
    src = {
        "https://github.com/folke/tokyonight.nvim",
    },
    setup = function()
        vim.cmd.colorscheme("tokyonight")
    end,
}
