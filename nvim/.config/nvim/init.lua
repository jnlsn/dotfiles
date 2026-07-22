-- Leader keys must be set before lazy.nvim loads so plugin mappings register
-- against the intended leader.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")
require("config.lazy")
