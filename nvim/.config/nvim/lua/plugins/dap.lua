-- Debugging: nvim-dap with Python via debugpy. No debugpy install is needed: `setup("uv")` starts the
-- adapter with `uv run --with debugpy`, in the project's own environment (so the program is debugged
-- with the project's .venv). Values are inspected with nvim-dap's built-in widgets, no UI plugin.
vim.pack.add({
    "https://github.com/mfussenegger/nvim-dap",
    "https://github.com/mfussenegger/nvim-dap-python",
})

local dap = require("dap")
local widgets = require("dap.ui.widgets")

require("dap-python").setup("uv")

vim.fn.sign_define({
    { name = "DapBreakpoint", text = "●", texthl = "DiagnosticError" },
    { name = "DapBreakpointCondition", text = "◆", texthl = "DiagnosticWarn" },
    { name = "DapBreakpointRejected", text = "○", texthl = "DiagnosticHint" },
    { name = "DapLogPoint", text = "◇", texthl = "DiagnosticInfo" },
    { name = "DapStopped", text = "▶", texthl = "DiagnosticOk", linehl = "CursorLine" },
})

local function map(lhs, rhs, desc, mode)
    vim.keymap.set(mode or "n", lhs, rhs, { desc = desc })
end

map("<leader>db", dap.toggle_breakpoint, "Toggle breakpoint")
map("<leader>dB", function()
    dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, "Conditional breakpoint")
map("<leader>dc", dap.continue, "Start / continue")
map("<leader>dn", dap.step_over, "Step over")
map("<leader>di", dap.step_into, "Step into")
map("<leader>do", dap.step_out, "Step out")
map("<leader>dr", dap.run_to_cursor, "Run to cursor")
map("<leader>dl", dap.run_last, "Run last configuration")
map("<leader>dt", dap.terminate, "Terminate session")

-- Inspect: the value under the cursor (or the selection), the current scopes and the call stack
map("<leader>dh", widgets.hover, "Hover value", { "n", "v" })
local scopes = widgets.sidebar(widgets.scopes)
local frames = widgets.sidebar(widgets.frames)
map("<leader>ds", scopes.toggle, "Toggle scopes (variables)")
map("<leader>df", frames.toggle, "Toggle call stack")
map("<leader>dR", dap.repl.toggle, "Toggle REPL")
