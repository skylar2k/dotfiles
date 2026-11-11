local M = {}

-- Indent for assembly in the usual GNU as layout (what `cc -S` writes): labels and preprocessor lines in column 0,
-- instructions and directives one level in. Comment lines keep their indent. Used as 'indentexpr' (ftplugin/asm.lua).
function M.indent(lnum)
    local line = vim.fn.getline(lnum or vim.v.lnum)
    if line:match("^%s*[%w_.$]+:") or line:match("^%s*#") then
        return 0
    end
    if line:match("^%s*//") or line:match("^%s*/%*") or line:match("^%s*%*") or line:match("^%s*[@;]") then
        return -1
    end
    return vim.fn.shiftwidth()
end

return M
