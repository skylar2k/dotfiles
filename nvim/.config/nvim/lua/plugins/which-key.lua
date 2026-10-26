vim.pack.add({
    "https://github.com/folke/which-key.nvim",
})

-- Regular mappings are defined next to their plugin (with a `desc`).
-- Here: group names, plus the which-key-only features (proxy, expand).
require("which-key").add({
    { "<leader>f", group = "files" },
    { "<leader>w", proxy = "<c-w>",  group = "windows" },
    { "<leader>b", group = "buffers" },
    { "<leader>c", group = "code" },
    { "<leader>d", group = "debug" },
    { "<leader>g", group = "git" },
    { "<leader>p", group = "project" },
    { "<leader>r", group = "run" },
    { "<leader>t", group = "test" },
})
