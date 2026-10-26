local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.scrolloff = 8
opt.wrap = false

-- Editing
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 4
opt.smartindent = true
opt.clipboard = "unnamedplus"
opt.undofile = true

-- Search
opt.ignorecase = true
opt.smartcase = true

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Completion: built-in popup as you type. Sources: current buffer, windows, loaded buffers and
-- the buffer's omnifunc ("o", which is the language server when one is attached).
-- Accept with <C-y>, navigate with <Tab>/<S-Tab> (keymaps.lua).
opt.autocomplete = true
opt.complete = ".^5,w^5,b^5,o"
opt.completeopt = { "menu", "menuone", "popup", "noselect" }

-- Timing
opt.updatetime = 250
opt.timeoutlen = 400
