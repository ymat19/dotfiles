-- general settings
vim.opt.number = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true  -- デフォルトで大文字・小文字を無視
vim.opt.smartcase = true   -- 大文字が含まれる場合は大文字・小文字を区別
vim.opt.scrolloff = 5
vim.o.expandtab = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true
vim.opt.clipboard:append({ "unnamed", "unnamedplus" })
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.undofile = true


-- key bindings
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', 'jk', '<ESC>:w<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<CR>', ':nohlsearch<CR>', { noremap = true, silent = true })

