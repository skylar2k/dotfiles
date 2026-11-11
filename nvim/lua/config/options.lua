local opt = vim.opt

-- Options newer than some Neovim this config runs on (servers): set only where they exist
local function set_new(name, value)
	if vim.fn.exists("+" .. name) == 1 then
		opt[name] = value
	end
end

-- UI
opt.number = true -- with relativenumber: the cursor line shows its absolute number, for `42gg`
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.scrolloff = 8
opt.wrap = false
set_new("winborder", "rounded")
opt.showmode = false -- the statusline shows the mode (config/statusline.lua)
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.confirm = true -- ask instead of failing when quitting with unsaved changes

-- Editing
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
vim.g.markdown_recommended_style = 0 -- don't let Neovim's Markdown settings force 4 (ftplugin/markdown.lua sets 2)
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
-- Accept with <C-y>, pick with <C-n>/<C-p>; <Tab> never touches the menu (keymaps.lua).
set_new("autocomplete", true)
opt.complete = ".^5,w^5,b^5,o"
opt.completeopt = { "menu", "menuone", "popup", "noselect" }
set_new("completeitemalign", "kind,abbr,menu") -- icon first, then the label, then the signature
set_new("pumborder", "rounded") -- 'winborder' does not apply to the completion menu
opt.pumheight = 12
set_new("pummaxwidth", 60) -- long signatures are cut instead of stretching the menu

-- Timing
opt.updatetime = 250
opt.timeoutlen = 400
