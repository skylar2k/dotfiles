-- nvim-treesitter (main branch) only installs parsers and queries; highlighting is started in
-- config/autocmds.lua. Lua, Markdown, Vim, vimdoc and query parsers ship with Neovim.
return {
	profile = "full",
	requires = { "tree-sitter", "cc" },
	src = {
		"https://github.com/nvim-treesitter/nvim-treesitter",
	},
	setup = function()
		local ts = require("nvim-treesitter")
		ts.setup()

		-- Installs only what is missing, asynchronously (:checkhealth nvim-treesitter shows the state)
		local install = ts.install({
			"python", "bash", "zsh", "json", "toml", "yaml", "regex", "diff", "gitcommit",
			"zig", "asm",
		})
		if vim.env.NVIM_BOOTSTRAP then
			install:wait(300000) -- chezmoi's nvim-plugins script runs nvim headless; don't quit before the parsers are built
		end
	end,
}
