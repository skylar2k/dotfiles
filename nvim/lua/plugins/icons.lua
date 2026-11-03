-- One icon provider is enough; oil and which-key use mini.icons directly
return {
    profile = "lite",
    src = {
        "https://github.com/nvim-mini/mini.icons",
    },
    setup = function()
        require("mini.icons").setup()
        -- Telescope only knows nvim-web-devicons, so let mini.icons answer for it
        MiniIcons.mock_nvim_web_devicons()
    end,
}
