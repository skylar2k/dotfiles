-- Leaders must be set before plugins load
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")
require("config.autocmds")
local plugins = require("config.plugins")
-- Language servers and their keys only on workstations; NVIM_PROFILE=lite skips them
if plugins.profile == "full" then
    require("config.lsp")
end
require("config.statusline")
