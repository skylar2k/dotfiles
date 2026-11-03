local M = {}

-- The nearest ancestor directory containing any of these is the project root.
-- (A nested list means equal priority; a flat list would prefer the first marker anywhere above.)
M.markers = { { ".git", "pyproject.toml", "package.json", "Cargo.toml", "go.mod", "Makefile" } }

-- Directory of the current buffer: the listed directory in oil, the file's directory otherwise.
function M.dir()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype == "oil" then
        local dir = require("oil").get_current_dir(buf)
        if dir then
            return (dir:gsub("(.)/$", "%1"))
        end
    end
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and vim.bo[buf].buftype == "" then
        return vim.fs.dirname(name)
    end
    return vim.fn.getcwd()
end

-- Project root for `dir` (default: the current buffer's directory), or `dir` itself if none is found.
function M.root(dir)
    dir = dir or M.dir()
    return vim.fs.root(dir, M.markers) or dir
end

local function short(path)
    return vim.fn.fnamemodify(path, ":~")
end

-- Change Neovim's working directory (Telescope, :find and the like follow it).
function M.set_cwd(dir)
    vim.cmd.cd(vim.fn.fnameescape(dir))
    vim.notify("cwd: " .. short(dir))
end

function M.set_root()
    M.set_cwd(M.root())
end

function M.set_dir()
    M.set_cwd(M.dir())
end

function M.show_cwd()
    vim.notify("cwd: " .. short(vim.fn.getcwd()) .. "\nroot: " .. short(M.root()))
end

function M.open_root()
    require("oil").open(M.root())
end

-- Oil winbar: the directory being shown, with ~ for home.
function M.winbar()
    local dir = require("oil").get_current_dir(vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0))
    return dir and "  " .. short(dir):gsub("%%", "%%%%") or ""
end

return M
