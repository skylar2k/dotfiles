-- Markdown buffers: prose settings, and a toggle for the rendering.
vim.opt_local.wrap = true
vim.opt_local.linebreak = true -- wrap at word boundaries
vim.opt_local.breakindent = true
vim.opt_local.spell = false
-- Nested list items go under the text of their parent ("- " is 2 wide), which is also where prettier puts them.
-- Neovim's own Markdown settings use 4.
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2
vim.opt_local.tabstop = 2

vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown buf_toggle<cr>", { buffer = true, desc = "Toggle rendering" })
