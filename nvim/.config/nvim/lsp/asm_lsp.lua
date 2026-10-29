-- Assembly: hover docs for instructions, completion and diagnostics (it calls clang/gcc).
-- Which assembler and instruction set to use comes from a .asm-lsp.toml: the global default for
-- this machine is ~/.config/asm-lsp/.asm-lsp.toml (ARM64, GNU syntax); a project can override it
-- with its own .asm-lsp.toml in the project root.
---@type vim.lsp.Config
return {
    cmd = { "asm-lsp" },
    filetypes = { "asm", "vmasm" },
    root_markers = { ".asm-lsp.toml", ".git" },
    handlers = {
        -- asm-lsp sends every diagnostic several times (once per compiler run): keep one of each
        ["textDocument/publishDiagnostics"] = function(err, result, ctx)
            if result and result.diagnostics then
                local seen, unique = {}, {}
                for _, d in ipairs(result.diagnostics) do
                    local key = vim.json.encode({ d.range, d.severity, d.message })
                    if not seen[key] then
                        seen[key] = true
                        table.insert(unique, d)
                    end
                end
                result.diagnostics = unique
            end
            return vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
        end,
    },
}
