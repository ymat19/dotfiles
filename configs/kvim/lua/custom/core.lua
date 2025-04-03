-- general settings
vim.opt.number = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true -- デフォルトで大文字・小文字を無視
vim.opt.smartcase = true -- 大文字が含まれる場合は大文字・小文字を区別
vim.opt.scrolloff = 5
vim.o.expandtab = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.undofile = true
vim.opt.termguicolors = true
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

-- key bindings
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', 'jk', '<ESC>:w<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<CR>', ':nohlsearch<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'L', ':bnext<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'H', ':bprevious<CR>', { noremap = true, silent = true })

-- Common Pugins
require('substitute').setup {}

-- avoid confilict: surround, leap
require('nvim-surround').setup {}
vim.api.nvim_del_keymap('v', 'S')
vim.keymap.set({ 'n', 'x', 'o' }, 's', '<Plug>(leap-forward)')
vim.keymap.set({ 'n', 'x', 'o' }, 'S', '<Plug>(leap-backward)')

-- substitute-nvim
vim.keymap.set('n', 'rr', require('substitute').operator, { noremap = true })
vim.keymap.set('n', 'R', require('substitute').eol, { noremap = true })
vim.keymap.set('n', 'RR', require('substitute').line, { noremap = true })
vim.keymap.set('x', 'rr', require('substitute').visual, { noremap = true })

-- clever-f
vim.g.clever_f_smart_case = 1
vim.g.clever_f_fix_key_direction = 1
vim.g.clever_f_chars_match_any_signs = ';'
vim.keymap.set('n', ';', '<Plug>(clever-f-repeat-forward)', { noremap = false })
vim.keymap.set('n', ',', '<Plug>(clever-f-repeat-back)', { noremap = false })

-- dial
local augend = require 'dial.augend'
require('dial.config').augends:register_group {
  default = {
    augend.integer.alias.decimal,
    augend.integer.alias.hex,
    augend.constant.alias.bool,
    augend.date.alias['%Y/%m/%d'],
  },
}
vim.keymap.set('n', '<C-a>', function()
  require('dial.map').manipulate('increment', 'normal')
end)
vim.keymap.set('n', '<C-x>', function()
  require('dial.map').manipulate('decrement', 'normal')
end)
vim.keymap.set('n', 'g<C-a>', function()
  require('dial.map').manipulate('increment', 'gnormal')
end)
vim.keymap.set('n', 'g<C-x>', function()
  require('dial.map').manipulate('decrement', 'gnormal')
end)
vim.keymap.set('v', '<C-a>', function()
  require('dial.map').manipulate('increment', 'visual')
end)
vim.keymap.set('v', '<C-x>', function()
  require('dial.map').manipulate('decrement', 'visual')
end)
vim.keymap.set('v', 'g<C-a>', function()
  require('dial.map').manipulate('increment', 'gvisual')
end)
vim.keymap.set('v', 'g<C-x>', function()
  require('dial.map').manipulate('decrement', 'gvisual')
end)
