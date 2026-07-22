return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        -- Native sorter needs a C toolchain; skip it gracefully otherwise.
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({})
      pcall(telescope.load_extension, "fzf")

      local builtin = require("telescope.builtin")
      local map = vim.keymap.set
      map("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      map("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
      map("n", "<leader>fb", builtin.buffers, { desc = "Find open buffers" })
      map("n", "<leader>fh", builtin.help_tags, { desc = "Find help tags" })
      map("n", "<leader>fr", builtin.oldfiles, { desc = "Find recent files" })
      map("n", "<leader>fd", builtin.diagnostics, { desc = "Find diagnostics" })
      map("n", "<leader><leader>", builtin.buffers, { desc = "Find open buffers" })
    end,
  },
}
