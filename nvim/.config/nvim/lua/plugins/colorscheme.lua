return {
  {
    "folke/tokyonight.nvim",
    lazy = false, -- load during startup so it applies before other UI
    priority = 1000, -- ...and before any other plugin
    config = function()
      require("tokyonight").setup({ style = "night" })
      vim.cmd.colorscheme("tokyonight")
    end,
  },
}
