-- Renders Markdown in the buffer (headings, code blocks, tables, checkboxes, callouts, wiki links).
-- It works on every Markdown file, in a vault or not. Needs the markdown and markdown_inline treesitter
-- parsers, which ship with Neovim.
-- The raw text of the line under the cursor is shown while you edit it.
return {
    profile = "full",
    src = {
        "https://github.com/MeanderingProgrammer/render-markdown.nvim",
    },
    setup = function()
        -- The plugin's completion server runs inside Neovim and answers at once, so Neovim's LSP
        -- completion calls complete() while still inside the omnifunc that 'autocomplete' runs:
        -- E565. Answer on the next tick instead, like a real server.
        local lsp = require("render-markdown.integ.lsp")
        local server = lsp.server
        lsp.server = function(dispatchers)
            local rpc = server(dispatchers)
            local request = rpc.request
            rpc.request = function(method, params, callback)
                return request(method, params, function(...)
                    local args = { ... }
                    vim.schedule(function()
                        callback(unpack(args, 1, 3))
                    end)
                end)
            end
            return rpc
        end

        require("render-markdown").setup({
            file_types = { "markdown" },
            -- Insert mode shows the plain text; normal, command and terminal modes show the rendering
            render_modes = { "n", "c", "t" },
            completions = { lsp = { enabled = true } },
            latex = { enabled = false }, -- no math rendering
        })
    end,
}
