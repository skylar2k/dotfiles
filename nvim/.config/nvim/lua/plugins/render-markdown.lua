-- Renders Markdown in the buffer (headings, code blocks, tables, checkboxes, callouts, wiki links).
-- It works on every Markdown file, in a vault or not. Needs the markdown and markdown_inline treesitter
-- parsers, which ship with Neovim.
-- The raw text of the line under the cursor is shown while you edit it.
vim.pack.add({
    "https://github.com/MeanderingProgrammer/render-markdown.nvim",
})

require("render-markdown").setup({
    file_types = { "markdown" },
    -- Insert mode shows the plain text; normal, command and terminal modes show the rendering
    render_modes = { "n", "c", "t" },
    completions = { lsp = { enabled = true } },
    latex = { enabled = false }, -- no math rendering
})
