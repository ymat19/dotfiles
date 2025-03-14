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


-- key bindings
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', 'jk', '<ESC>:w<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<CR>', ':nohlsearch<CR>', { noremap = true, silent = true })


-- plugins setup
require'substitute'.setup{}
require'lspconfig'.nixd.setup{}
require("hardtime").setup()
require('neoscroll').setup({ mappings = {'<C-u>', '<C-d>'} })

-- avoid confilict: surround, leap
require'nvim-surround'.setup{}
vim.api.nvim_del_keymap('v', 'S')
require('leap').create_default_mappings()

-- treesitter
require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
  },
}

require("oil").setup()
vim.keymap.set("n", "-", "<CMD>vs<CR><CMD>Oil<CR>", { desc = "Open parent directory" })
vim.keymap.set("n", "_", "<CMD>vnew<CR><CMD>Oil<CR>", { desc = "Open parent directory" })

vim.cmd[[colorscheme tokyonight]]

-- quick scope https://zenn.dev/neo/scraps/49266fed7ce6b6
vim.cmd[[highlight QuickScopePrimary guifg='#afff5f' gui=underline ctermfg=155 cterm=underline]]
vim.cmd[[highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline]]

-- substitute-nvim
vim.keymap.set("n", "R", require('substitute').operator, { noremap = true })
vim.keymap.set("n", "RR", require('substitute').line, { noremap = true })
vim.keymap.set("x", "R", require('substitute').visual, { noremap = true })

-- vim-expand-region
vim.keymap.set('n', 'K', '<Plug>(expand_region_expand)', { noremap = false, silent = true })
vim.keymap.set('x', 'K', '<Plug>(expand_region_expand)', { noremap = false, silent = true })
vim.keymap.set('x', 'J', '<Plug>(expand_region_shrink)', { noremap = false, silent = true })

-- clever-f
vim.g.clever_f_smart_case = 1
vim.g.clever_f_fix_key_direction = 1
vim.g.clever_f_chars_match_any_signs = ";"

