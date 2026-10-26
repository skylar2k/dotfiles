vim.pack.add({
    "https://github.com/lewis6991/gitsigns.nvim",
})

require("gitsigns").setup({
    on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
        end

        map("]c", function()
            if vim.wo.diff then
                vim.cmd.normal({ "]c", bang = true })
            else
                gs.nav_hunk("next")
            end
        end, "Next hunk")
        map("[c", function()
            if vim.wo.diff then
                vim.cmd.normal({ "[c", bang = true })
            else
                gs.nav_hunk("prev")
            end
        end, "Previous hunk")

        map("<leader>gp", gs.preview_hunk, "Preview hunk")
        map("<leader>gs", gs.stage_hunk, "Stage/unstage hunk")
        map("<leader>gr", gs.reset_hunk, "Reset hunk")
        map("<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
    end,
})
