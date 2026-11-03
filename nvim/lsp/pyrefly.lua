---@type vim.lsp.Config
return {
	cmd = { "pyrefly", "lsp" },
	filetypes = { "python" },
	root_markers = { "pyrefly.toml", "pyproject.toml", "setup.py", "mypy.ini", "pyrightconfig.json", ".git" },
	-- Pyrefly finds a project's .venv (uv's default) by itself. An active venv wins over it.
	settings = {
		python = {
			-- Without these the server sends no inlay hints to Neovim (see <leader>ch in config/lsp.lua).
			-- callArgumentNames: "off" | "partial" (only where the value doesn't already say it) | "all"
			analysis = {
				-- How long you must stop editing before the server computes new hints (default 150).
				-- Until then the old hints stay where they are, so nothing flickers while you type.
				inlayHintDebounceMs = 1000,
				inlayHints = {
					callArgumentNames = "partial",
					functionReturnTypes = true,
					variableTypes = true,
				},
			},
			-- For stricter diagnostics without a pyrefly.toml (default mode is "auto"):
			-- pyrefly = { typeCheckingMode = "default" },
		},
	},
}
