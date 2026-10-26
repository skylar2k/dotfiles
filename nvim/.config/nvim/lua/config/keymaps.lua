local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit" })

-- Buffers (window navigation comes from the <leader>w proxy in which-key)
map("n", "<leader>bd", function() require("util.buffer").delete(false) end, { desc = "Delete buffer" })
map("n", "<leader>bD", function() require("util.buffer").delete(true) end, { desc = "Delete buffer (discard changes)" })

-- Keep selection when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")
