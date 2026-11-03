-- Auto-close brackets and quotes
return {
    profile = "lite",
    src = {
        "https://github.com/nvim-mini/mini.pairs",
    },
    setup = function()
        require("mini.pairs").setup()
    end,
}
