local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit" })

-- Buffers (window navigation comes from the <leader>w proxy in which-key)
map("n", "<leader>bd", function() require("util.buffer").delete(false) end, { desc = "Delete buffer" })
map("n", "<leader>bD", function() require("util.buffer").delete(true) end, { desc = "Delete buffer (discard changes)" })

-- Completion menu: <Tab>/<S-Tab> move through items while it is open
map("i", "<Tab>", function() return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>" end, { expr = true })
map("i", "<S-Tab>", function() return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>" end, { expr = true })

-- Keep selection when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")
