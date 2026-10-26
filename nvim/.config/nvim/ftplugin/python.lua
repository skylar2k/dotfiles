-- Python buffers: run the file or its tests, using uv when the project is managed by it.
-- Test failures land in the quickfix list (:cnext / :cprev to walk them), parsed with the
-- errorformat from `:compiler pytest`. Tests run from the current working directory:
-- set it first with <leader>pr (project root).
vim.cmd.compiler("pytest")

local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = true, desc = desc })
end

-- "uv run " when a uv.lock is found from the working directory upwards, which is where uv looks too
local function runner()
    return vim.fs.find("uv.lock", { upward = true, path = vim.fn.getcwd() })[1] and "uv run " or ""
end

-- Runs pytest in the background; each failure becomes a quickfix entry "file:line  message"
local function pytest(target)
    -- --tb=line prints one `file:line: message` per failure, which is exactly what quickfix wants
    local cmd = vim.list_extend(vim.split(runner(), " ", { trimempty = true }), { "pytest", "--tb=line" })
    if target then
        table.insert(cmd, target)
    end
    local efm = vim.bo.errorformat
    local ok, err = pcall(
        vim.system,
        cmd,
        { text = true },
        vim.schedule_wrap(function(res)
            local lines = vim.split((res.stdout or "") .. (res.stderr or ""), "\n", { trimempty = true })
            -- Keep only entries that point at a file and line, so :cnext / :cprev walk real failures
            local items = vim.tbl_filter(function(item)
                return item.valid == 1 and item.bufnr > 0 and item.lnum > 0
            end, vim.fn.getqflist({ lines = lines, efm = efm }).items)
            vim.fn.setqflist({}, " ", { title = table.concat(cmd, " "), items = items })

            if res.code == 0 then
                vim.notify("pytest: passed")
            elseif #items > 0 then
                vim.notify(("pytest: %d failed"):format(#items), vim.log.levels.WARN)
                vim.cmd("copen")
            else -- e.g. "no tests ran", a crash or a collection problem without a location
                vim.notify("pytest: " .. vim.trim(lines[#lines] or "failed"), vim.log.levels.WARN)
            end
        end)
    )
    if not ok then
        vim.notify("Could not run " .. table.concat(cmd, " ") .. ": " .. err, vim.log.levels.ERROR)
    end
end

-- "Class::test_name" (or just "test_name") for the test around the cursor; nested helpers are ignored
local function nearest_test()
    local chain = {}
    local node = vim.treesitter.get_node()
    while node do
        local kind = node:type()
        local name = (kind == "function_definition" or kind == "class_definition") and node:field("name")[1]
        if name then
            table.insert(chain, 1, { kind = kind, name = vim.treesitter.get_node_text(name, 0) })
        end
        node = node:parent()
    end
    local parts = {}
    for _, item in ipairs(chain) do
        table.insert(parts, item.name)
        if item.kind == "function_definition" then
            break
        end
    end
    return #parts > 0 and table.concat(parts, "::") or nil
end

map("<leader>tt", function()
    pytest()
end, "Run all tests")
map("<leader>tf", function()
    pytest(vim.fn.expand("%:."))
end, "Run tests in this file")
map("<leader>tn", function()
    local test = nearest_test()
    if not test then
        vim.notify("No test function or class around the cursor", vim.log.levels.WARN)
        return
    end
    pytest(vim.fn.expand("%:.") .. "::" .. test)
end, "Run the test under the cursor")

map("<leader>dT", function()
    require("dap-python").test_method()
end, "Debug the test under the cursor")

map("<leader>rr", function()
    local file = vim.fn.expand("%:p")
    vim.cmd("botright split")
    vim.cmd.terminal(runner() .. "python " .. vim.fn.shellescape(file))
end, "Run this file in a terminal")
