return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    main = "nvim-treesitter.configs",
    opts = {
      ensure_installed = {
        "bash", "c", "diff", "dockerfile", "go", "javascript", "json",
        "lua", "luadoc", "markdown", "markdown_inline", "python", "query",
        "rust", "toml", "tsx", "typescript", "vim", "vimdoc", "yaml",
      },
      auto_install = true, -- install parsers for other filetypes on demand
      highlight = { enable = true },
      indent = { enable = true },
    },
  },
}
