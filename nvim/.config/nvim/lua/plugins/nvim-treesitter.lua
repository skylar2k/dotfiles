-- nvim-treesitter (main branch) only installs parsers and queries; highlighting is started below.
-- Needs the `tree-sitter` CLI and a C compiler. Lua, Markdown, Vim, vimdoc and query parsers ship with Neovim.
vim.pack.add({
	"https://github.com/nvim-treesitter/nvim-treesitter",
})

local ts = require("nvim-treesitter")
ts.setup()

-- Installs only what is missing, asynchronously (:checkhealth nvim-treesitter shows the state)
local install = ts.install({ "python", "bash", "zsh", "json", "toml", "yaml", "regex", "diff", "gitcommit" })
if vim.env.NVIM_BOOTSTRAP then
	install:wait(300000) -- bootstrap.sh runs nvim headless; don't quit before the parsers are built
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("config.treesitter", {}),
	callback = function(ev)
		pcall(vim.treesitter.start, ev.buf) -- no parser for this filetype: keep regex syntax
	end,
})
