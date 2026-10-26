-- Example plugin spec: add more files like this one to lua/plugins/
return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000, -- load before everything else
    config = function()
        vim.cmd.colorscheme("tokyonight")
    end,
}
