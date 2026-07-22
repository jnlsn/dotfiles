local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.scrolloff = 10
opt.showmode = false -- shown in the statusline instead
opt.termguicolors = true
opt.splitright = true
opt.splitbelow = true

-- Whitespace made visible
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Indentation (2 spaces; treesitter/LSP handle language-specific overrides)
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.breakindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split" -- live preview of :substitute

-- Behaviour
opt.mouse = "a"
opt.clipboard = "unnamedplus" -- share with the system clipboard
opt.undofile = true -- persist undo history across sessions
opt.updatetime = 250
opt.timeoutlen = 300
opt.confirm = true -- prompt instead of failing on unsaved changes
