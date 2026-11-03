-- Regular mappings are defined next to their plugin (with a `desc`).
-- Here: group names, plus the which-key-only features (proxy, expand).
return {
    profile = "lite",
    src = {
        "https://github.com/folke/which-key.nvim",
    },
    setup = function()
        require("which-key").add({
            { "<leader>f", group = "files" },
            { "<leader>w", proxy = "<c-w>",  group = "windows" },
            { "<leader>b", group = "buffers" },
            { "<leader>c", group = "code" },
            { "<leader>d", group = "debug" },
            { "<leader>g", group = "git" },
            { "<leader>m", group = "markdown" },
            { "<leader>o", group = "obsidian" },
            { "<leader>p", group = "project" },
            { "<leader>r", group = "run" },
            { "<leader>t", group = "test" },
        })
    end,
}
