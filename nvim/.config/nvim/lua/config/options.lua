local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.scrolloff = 8
opt.wrap = false
opt.winborder = "rounded"
opt.showmode = false -- the statusline shows the mode (config/statusline.lua)
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.confirm = true -- ask instead of failing when quitting with unsaved changes

-- Editing
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true
opt.clipboard = "unnamedplus"
opt.undofile = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split" -- live preview of :s in a split

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Folding: treesitter by default, the language server when it offers folds (config/lsp.lua).
-- Everything starts open; `zM` collapses a file to an outline of its classes and functions,
-- `za` toggles one fold and `zR` opens all.
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevelstart = 99
opt.foldtext = "" -- show the folded line itself, with syntax highlighting

-- Completion: built-in popup as you type. Sources: current buffer, windows, loaded buffers and
-- the buffer's omnifunc ("o", which is the language server when one is attached).
-- Accept with <C-y>, navigate with <Tab>/<S-Tab> (keymaps.lua).
opt.autocomplete = true
opt.complete = ".^5,w^5,b^5,o"
opt.completeopt = { "menu", "menuone", "popup", "noselect" }

-- Timing
opt.updatetime = 250
opt.timeoutlen = 400
