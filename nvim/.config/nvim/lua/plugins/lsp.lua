return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      { "williamboman/mason.nvim", opts = {} },
      "williamboman/mason-lspconfig.nvim",
      { "j-hui/fidget.nvim", opts = {} }, -- LSP progress in the bottom-right
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      -- Buffer-local keymaps, set only once a language server attaches.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
        callback = function(event)
          local builtin = require("telescope.builtin")
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end
          map("gd", builtin.lsp_definitions, "Goto definition")
          map("gr", builtin.lsp_references, "Goto references")
          map("gI", builtin.lsp_implementations, "Goto implementation")
          map("<leader>D", builtin.lsp_type_definitions, "Type definition")
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("K", vim.lsp.buf.hover, "Hover documentation")
          map("<leader>f", function()
            vim.lsp.buf.format({ async = true })
          end, "Format buffer")
        end,
      })

      -- Advertise nvim-cmp's completion capabilities to every server.
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      vim.lsp.config("*", { capabilities = capabilities })

      -- mason-lspconfig installs these and enables them (via vim.lsp.enable)
      -- using the default configs shipped by nvim-lspconfig.
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "bashls",
          "pyright",
          "ts_ls",
          "gopls",
          "rust_analyzer",
          "jsonls",
          "yamlls",
        },
        automatic_enable = true,
      })
    end,
  },
}
