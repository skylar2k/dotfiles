local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit" })

-- Buffers (window navigation comes from the <leader>w proxy in which-key)
map("n", "<leader>bd", function() require("util.buffer").delete(false) end, { desc = "Delete buffer" })
map("n", "<leader>bD", function() require("util.buffer").delete(true) end, { desc = "Delete buffer (discard changes)" })

-- Project: Telescope, :find and friends follow the working directory
map("n", "<leader>pr", function() require("util.project").set_root() end, { desc = "Set cwd to project root" })
map("n", "<leader>pd", function() require("util.project").set_dir() end, { desc = "Set cwd to this directory" })
map("n", "<leader>pw", function() require("util.project").show_cwd() end, { desc = "Show cwd and project root" })

-- <Tab>/<S-Tab> never touch the completion menu, which opens as you type. Pick with <C-n>/<C-p>,
-- accept with <C-y>. Tab jumps through snippet fields, or indents; <S-Tab> jumps back, or dedents.
local function tab(direction, fallback)
    return function()
        if vim.snippet.active({ direction = direction }) then
            vim.schedule(function() vim.snippet.jump(direction) end)
            return ""
        end
        return fallback
    end
end

map("i", "<Tab>", tab(1, "<Tab>"), { expr = true, desc = "Next snippet field or indent" })
map("i", "<S-Tab>", tab(-1, "<C-d>"), { expr = true, desc = "Previous snippet field or dedent" })

-- Keep selection when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")
