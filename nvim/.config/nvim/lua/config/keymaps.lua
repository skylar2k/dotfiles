local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Keep selection when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")
