---@type vim.lsp.Config
return {
    cmd = { "pyrefly", "lsp" },
    filetypes = { "python" },
    root_markers = { "pyrefly.toml", "pyproject.toml", "setup.py", "mypy.ini", "pyrightconfig.json", ".git" },
    -- Pyrefly finds a project's .venv (uv's default) by itself. An active venv wins over it.
    -- For stricter diagnostics without a pyrefly.toml (default mode is "auto"):
    -- settings = { python = { pyrefly = { typeCheckingMode = "default" } } },
}
