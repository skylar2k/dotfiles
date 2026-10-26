vim.pack.add({
    "https://github.com/folke/which-key.nvim",
})

local wk = require("which-key")
wk.add({
    { "<leader>f",  group = "file" }, -- group
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find File", mode = "n" },
    { "<leader>fb", function() print("hello") end,   desc = "Foobar" },
    { "<leader>fn", desc = "New File" },
    { "<leader>w",  proxy = "<c-w>",                 group = "windows" }, -- proxy to window mappings
    {
        "<leader>b",
        group = "buffers",
        expand = function()
            return require("which-key.extras").expand.buf()
        end
    },
    {
        -- Nested mappings are allowed and can be added in any order
        -- Most attributes can be inherited or overridden on any level
        -- There's no limit to the depth of nesting
        mode = { "n", "v" },                          -- NORMAL and VISUAL mode
        { "<leader>q", "<cmd>q<cr>", desc = "Quit" }, -- no need to specify mode since it's inherited
    }
})
