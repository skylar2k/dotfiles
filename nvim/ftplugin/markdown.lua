-- Markdown buffers: prose settings, and a toggle for the rendering.
vim.opt_local.wrap = true
vim.opt_local.linebreak = true -- wrap at word boundaries
vim.opt_local.breakindent = true
vim.opt_local.spell = false

vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown buf_toggle<cr>", { buffer = true, desc = "Toggle rendering" })
