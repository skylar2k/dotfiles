-- Assembly buffers: labels go to column 0 as soon as you type their ":", instructions and directives one level in.
-- `=` reindents the same way (`gg=G` for the whole file).
vim.opt_local.indentexpr = "v:lua.require'util.asm'.indent()"
-- Reindent on ":" (labels) and "#" (preprocessor) in the line's first word, and on new lines
vim.opt_local.indentkeys = "0#,<:>,!^F,o,O"
-- One level is 2 spaces
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2
vim.opt_local.tabstop = 2
