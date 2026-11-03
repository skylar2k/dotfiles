-- telescope-fzf-native is built by the PackChanged hook in config/plugins.lua; without `make` and a
-- C compiler it is left out and Telescope uses its own (slower) sorter.
local has = function(exe)
    return vim.fn.executable(exe) == 1
end
local fzf = has("make") and has("cc")

local src = {
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/nvim-telescope/telescope.nvim",
}
if fzf then
    table.insert(src, "https://github.com/nvim-telescope/telescope-fzf-native.nvim")
end

return {
    profile = "lite",
    src = src,
    setup = function()
        -- Without rg or fd, find_files runs `find`, whose ./-prefixed paths slip past the .git pattern below
        local find_command
        if not (has("rg") or has("fd") or has("fdfind")) then
            find_command = { "find", ".", "-type", "f", "-not", "-path", "*/.git/*" }
        end

        require('telescope').setup {
            defaults = {
                -- Search hidden files, but never the contents of .git/
                file_ignore_patterns = { "^%.git/" },
                vimgrep_arguments = {
                    "rg", "--color=never", "--no-heading", "--with-filename",
                    "--line-number", "--column", "--smart-case", "--hidden",
                },
            },
            pickers = {
                find_files = { hidden = true, find_command = find_command },
            },
            extensions = {
                fzf = {
                    fuzzy = true,                   -- false will only do exact matching
                    override_generic_sorter = true, -- override the generic sorter
                    override_file_sorter = true,    -- override the file sorter
                    case_mode = "smart_case",       -- or "ignore_case" or "respect_case"
                    -- the default case_mode is "smart_case"
                }
            }
        }

        -- Warn instead of erroring if the build is missing, so startup isn't blocked
        if fzf then
            local ok, err = pcall(require("telescope").load_extension, "fzf")
            if not ok then
                vim.notify("telescope-fzf-native not loaded (missing build?):\n" .. err, vim.log.levels.WARN)
            end
        end

        -- Live grep needs rg; without it, prompt for a pattern and :grep it into the quickfix list
        local function grep()
            vim.ui.input({ prompt = "Grep: " }, function(pattern)
                if not pattern or pattern == "" then
                    return
                end
                vim.cmd.grep({
                    args = { "-r", "--exclude-dir=.git", vim.fn.shellescape(pattern), "." },
                    bang = true,
                    magic = { file = false, bar = false },
                    mods = { silent = true },
                })
                vim.cmd("botright copen")
            end)
        end

        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
        if has("rg") then
            vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
        else
            vim.keymap.set("n", "<leader>fg", grep, { desc = "Grep into quickfix" })
        end
        vim.keymap.set("n", "<leader>fD", builtin.diagnostics, { desc = "Diagnostics (project)" })
        vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Symbols (file)" })
        vim.keymap.set("n", "<leader>fS", builtin.lsp_dynamic_workspace_symbols, { desc = "Symbols (project, live)" })
        vim.keymap.set("n", "<leader>bb", builtin.buffers, { desc = "Search buffers" })
        vim.keymap.set("n", "<leader>?", builtin.help_tags, { desc = "Help tags" })

        vim.keymap.set("n", "<leader>fc", function()
            builtin.find_files({ cwd = vim.fn.stdpath("config") })
        end, { desc = "Find neovim config files" })

        vim.keymap.set("n", "<leader>fd", function()
            builtin.diagnostics({ bufnr = 0 })
        end, { desc = "Diagnostics (buffer)" })
    end,
}
