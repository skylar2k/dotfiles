-- YAML: schema validation and completion. With schemaStore the server picks a schema for well-known
-- files (GitHub workflows, docker-compose, Kubernetes manifests ...) from schemastore.org by file name.
-- Formatting is left to prettier (conform), so the server's own formatter is off.
---@type vim.lsp.Config
return {
    cmd = { "yaml-language-server", "--stdio" },
    filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab" },
    root_markers = { ".git" },
    settings = {
        redhat = { telemetry = { enabled = false } },
        yaml = {
            format = { enable = false },
            schemaStore = { enable = true, url = "https://www.schemastore.org/api/json/catalog.json" },
        },
    },
}
