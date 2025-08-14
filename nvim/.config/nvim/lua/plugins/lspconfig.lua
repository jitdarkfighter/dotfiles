local lsp_attach = function(event)
    -- Local helper function
    local map = function(keys, func, desc, mode)
        mode = mode or "n"
        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
    end

    local telescope = require("telescope.builtin")

    -- Rename variables
    map("grn", vim.lsp.buf.rename, "[R]e[n]ame")

    -- Execute a code action
    map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })

    -- Find references for the word under your cursor.
    map("grr", telescope.lsp_references, "[G]oto [R]eferences")

    -- Jump to the implementation of the word under your cursor.
    map("gri", telescope.lsp_implementations, "[G]oto [I]mplementation")

    -- Jump to the definition of the word under your cursor.
    map("gd", telescope.lsp_definitions, "[G]oto [D]efinition")

    -- Fuzzy find all the symbols in your current document.
    map("gO", telescope.lsp_document_symbols, "Open Document Symbols")

    -- Fuzzy find all the symbols in your current workspace.
    map("gW", telescope.lsp_dynamic_workspace_symbols, "Open Workspace Symbols")

    -- Jump to the type of the word under your cursor.
    map("grt", telescope.lsp_type_definitions, "[G]oto [T]ype Definition")

    -- Open floating diagnostic
    map("grd", vim.diagnostic.open_float, "[G]et Floating [D]iagnostic")

    local client = vim.lsp.get_client_by_id(event.data.client_id)

    -- Document highlights

    if
        client
        and client.supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
    then
        local highlight_augroup = vim.api.nvim_create_augroup("lsp-highlight", { clear = false })

        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
        })

        vim.api.nvim_create_autocmd("LspDetach", {
            group = vim.api.nvim_create_augroup("lsp-detach", { clear = true }),
            callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds({ group = "lsp-highlight", buffer = event2.buf })
            end,
        })
    end

    -- Toggle inlay hints
    if client and client.supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
        map("<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
        end, "[T]oggle Inlay [H]ints")
    end
end

local function diagnostic_config()
    local severity = vim.diagnostic.severity
    vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
        underline = { severity = { severity.ERROR } },
        signs = {
            text = {
                [severity.ERROR] = "󰅚 ",
                [severity.WARN] = "󰀪 ",
                [severity.INFO] = "󰋽 ",
                [severity.HINT] = "󰌶 ",
            },
        },
        virtual_text = {
            severity = {
                severity.INFO,
                severity.HINT,
            },
            source = true,
            spacing = 2,
        },
        virtual_lines = {
            severity = {
                severity.ERROR,
                severity.WARN,
            },
            format = function(diagnostic)
                return diagnostic.message .. " -- " .. diagnostic.source
            end,
        },
    })
end

return {
    {
        "folke/lazydev.nvim",
        opts = {
            library = {
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },
    {
        "mason-org/mason.nvim",
        opts = {
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗",
                },
            },
        },
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            -- Automatically install LSPs and related tools
            "mason-org/mason.nvim",
            "mason-org/mason-lspconfig.nvim",
            "WhoIsSethDaniel/mason-tool-installer.nvim",

            -- Status updates for LSP
            { "j-hui/fidget.nvim", opts = {} },

            -- Extra capabilities provided by blink.cmp
            "saghen/blink.cmp",
        },
        config = function()
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
                callback = lsp_attach,
            })

            diagnostic_config()

            local capabilities = require("blink.cmp").get_lsp_capabilities()
            vim.lsp.config("*", { capabilities = capabilities })

            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = {
                        completion = { callSnippet = "Both" },
                    },
                },
            })

            vim.lsp.config("pyright", {
                settings = {
                    python = {
                        analysis = {
                            diagnosticMode = "openFilesOnly",
                            typeCheckingMode = "basic",
                            diagnosticSeverityOverrides = {
                                reportUnusedImport = false,
                                -- reportUnusedExpression = false,
                            },
                        },
                    },
                    pyright = { disableOrganizeImports = true },
                },
            })

            vim.lsp.config("ruff", {
                on_attach = function(client, _)
                    if client.name == "ruff" then
                        client.server_capabilities.hoverProvider = false
                    end
                end,
            })

            -- Servers
            local ensure_installed = {
                "lua_ls",  -- Lua LSP
                "pyright", -- Python LSP
                "ruff",    -- Python linter
            }

            -- Additional
            vim.list_extend(ensure_installed, {
                "stylua",    -- Lua formatter
                "prettierd", -- Markdown formatter
                "isort",     -- Python imports formatter
                "black",     -- Python formatter
            })
            require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

            require("mason-lspconfig").setup()
        end,
    },
}
