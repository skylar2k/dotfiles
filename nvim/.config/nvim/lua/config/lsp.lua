-- Server definitions live in lsp/<name>.lua (found on the runtimepath by vim.lsp.config).
-- Each server binary has to be installed separately:
--   pyrefly: `brew install pyrefly` or `uv tool install pyrefly`
--   lua_ls:  `brew install lua-language-server`
local servers = { "lua_ls", "pyrefly" }

local missing = {}
for _, name in ipairs(servers) do
	local cmd = vim.lsp.config[name].cmd
	if cmd and vim.fn.executable(cmd[1]) == 1 then
		vim.lsp.enable(name)
	else
		table.insert(missing, ("%s (%s)"):format(name, cmd and cmd[1] or "no cmd"))
	end
end
if #missing > 0 then
	vim.schedule(function()
		vim.notify("LSP server not installed, skipped: " .. table.concat(missing, ", "), vim.log.levels.WARN)
	end)
end

vim.diagnostic.config({
	virtual_text = { source = "if_many" },
	severity_sort = true,
	float = { border = "rounded", source = "if_many" },
})

-- Completion menu: show an icon (coloured by mini.icons) in the kind column instead of the kind name
local function convert_completion(item)
	local name = vim.lsp.protocol.CompletionItemKind[item.kind]
	local ok, icons = pcall(require, "mini.icons")
	if not (name and ok) then
		return {}
	end
	local icon, hl = icons.get("lsp", name)
	return { kind = icon, kind_hlgroup = hl }
end

-- Neovim already maps K (hover), grn (rename), gra (code action), grr (references),
-- gri (implementation), gO (symbols), CTRL-S (signature help) and [d / ]d (diagnostics).
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("config.lsp", {}),
	callback = function(ev)
		local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))

		-- Completion itself is triggered by 'autocomplete' via omnifunc (see options.lua);
		-- enabling it here makes <C-y> apply snippets, import edits and other side effects.
		if client:supports_method("textDocument/completion") then
			vim.lsp.completion.enable(true, client.id, ev.buf, { convert = convert_completion })
			-- Only the server completes here: the buffer-word sources would list every identifier twice,
			-- because Neovim does not merge them with the server's items. <C-x><C-n> still completes
			-- from the current file's words.
			vim.bo[ev.buf].complete = "o"
		end

		-- Prefer the server's folding ranges over treesitter's when it has them (options.lua)
		if client:supports_method("textDocument/foldingRange") then
			vim.wo[vim.api.nvim_get_current_win()][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
		end

		vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf, desc = "Go to definition" })
	end,
})
