-- Images inline in Markdown: ![alt](path), ![[image.png]] Obsidian embeds and <img> tags are drawn below their line
-- with the kitty graphics protocol (Ghostty, kitty, WezTerm; inside tmux too). In other terminals nothing is shown.
-- PNG works as is; JPEG, WebP, HEIC, GIF and the rest are converted with ImageMagick (`magick`, in the Brewfile).
-- Only the image module of snacks.nvim is enabled.
local function in_vault(file, src)
    local vault = vim.fs.root(file, ".obsidian")
    if not vault or src:find("^%w%w+://") or src:sub(1, 1) == "/" then
        return nil
    end
    -- Obsidian links by the shortest unique path, often just the file name: try the attachments folder and the
    -- vault root, then anywhere in the vault
    for _, path in ipairs({ vault .. "/attachments/" .. src, vault .. "/" .. src }) do
        if vim.uv.fs_stat(path) then
            return path
        end
    end
    return vim.fs.find(vim.fs.basename(src), { path = vault, type = "file", limit = 1 })[1]
end

return {
    profile = "full",
    src = {
        { src = "https://github.com/folke/snacks.nvim", version = vim.version.range("*") },
    },
    setup = function()
        require("snacks").setup({
            image = {
                enabled = true,
                resolve = in_vault,
                doc = { max_width = 80, max_height = 30 },
                math = { enabled = false }, -- no LaTeX or Typst rendering
            },
        })

        vim.keymap.set("n", "<leader>mi", function()
            Snacks.image.hover()
        end, { desc = "Show the image under the cursor" })
    end,
}
