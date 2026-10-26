-- One icon provider is enough; oil and which-key use mini.icons directly
vim.pack.add({
    "https://github.com/nvim-mini/mini.icons",
})

require("mini.icons").setup()
-- Telescope only knows nvim-web-devicons, so let mini.icons answer for it
MiniIcons.mock_nvim_web_devicons()
