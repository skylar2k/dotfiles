-- Lazy
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        init = function()
            vim.o.timeout = true
            vim.o.timeoutlen = 300
        end
    }, {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.2",
        dependencies = {"nvim-lua/plenary.nvim"}
    }, {"folke/tokyonight.nvim", lazy = false, priority = 1000, opts = {}}, {
        "nvim-treesitter/nvim-treesitter",
        opt = {
            highlight = {enable = true},
            indent = {enable = true},
            ensure_installed = {
                "bash", "c", "html", "javascript", "json", "lua", "luadoc",
                "luap", "markdown", "markdown_inline", "python", "query",
                "regex", "tsx", "typescript", "vim", "vimdoc", "yaml"
            },
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "<C-space>",
                    node_incremental = "<C-space>",
                    scope_incremental = false,
                    node_decremental = "<bs>"
                }
            }
        }
    }
})

-- Variables
local wk = require("which-key")
local ts = require('telescope.builtin')

-- Keybindings
vim.g.mapleader = " "

wk.register({
    f = {
        name = "File",
        f = {ts.find_files, "Find file"},
        g = {ts.live_grep, "Live grep"}
    },
    b = {name = "Buffer", b = {ts.buffers, "Open buffers"}}
}, {prefix = "<leader>"})

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Visual
vim.opt.relativenumber = true
vim.cmd [[colorscheme tokyonight]]

-- Tab
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.autoindent = true
vim.opt.expandtab = true
