-- Assembly: hover docs for instructions, completion and diagnostics (it calls clang/gcc).
-- Which assembler and instruction set to use comes from a .asm-lsp.toml: the global default for
-- this machine is ~/.config/asm-lsp/.asm-lsp.toml (ARM64, GNU syntax; on macOS asm-lsp reads it
-- through a link in ~/Library/Application Support/asm-lsp); a project can override it with its
-- own .asm-lsp.toml in the project root.
---@type vim.lsp.Config
return {
    cmd = { "asm-lsp" },
    filetypes = { "asm", "vmasm" },
    root_markers = { ".asm-lsp.toml", ".git" },
    handlers = {
        -- asm-lsp warns "No .asm-lsp.toml config file found" in every project without its own file,
        -- even when it has read the global one: drop that warning
        ["window/showMessage"] = function(err, result, ctx)
            if result and result.message:find("No .asm-lsp.toml config file found", 1, true) then
                return
            end
            return vim.lsp.handlers["window/showMessage"](err, result, ctx)
        end,
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
