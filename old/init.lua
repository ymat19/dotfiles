-- リーダーキーをスペースに設定
vim.g.mapleader = ' '

-- インサートモードで jj でESCに、jk でESCして保存
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', 'jk', '<ESC>:w<CR>', { noremap = true, silent = true })

-- クリップボード設定
vim.opt.clipboard:append('unnamed')

-- jとkで行の折り返しを考慮するマッピング
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, silent = true })

-- Hで前のバッファ、Lで次のバッファに移動
--vim.api.nvim_set_keymap('n', 'H', ':bprevious<CR>', { noremap = true, silent = true })
--vim.api.nvim_set_keymap('n', 'L', ':bnext<CR>', { noremap = true, silent = true })

-- sで今の単語をヤンク済みのテキストで上書き（レジスタを汚さない）
vim.api.nvim_set_keymap('n', 's', '"_diwP', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'S', '"_diWP', { noremap = true, silent = true })

-- enterでハイライト無効
vim.opt.hlsearch = true
vim.api.nvim_set_keymap('n', '<CR>', ':nohlsearch<CR>', { noremap = true, silent = true })

-- 検索のスマートケース設定
vim.opt.ignorecase = true  -- デフォルトで大文字・小文字を無視
vim.opt.smartcase = true   -- 大文字が含まれる場合は大文字・小文字を区別

-- Ctrl+h で行の先頭に移動
vim.api.nvim_set_keymap('n', '<C-h>', '^', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-l>', '$', { noremap = true, silent = true })

-- タブ関連の設定
vim.o.expandtab = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true


-- プラグイン関係
require("config.lazy")


-- hlslens
--require('hlslens').setup()
--
--local kopts = {noremap = true, silent = true}
--
--vim.api.nvim_set_keymap('n', 'n',
--    [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
--    kopts)
--vim.api.nvim_set_keymap('n', 'N',
--    [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
--    kopts)
--vim.api.nvim_set_keymap('n', '*', [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
--vim.api.nvim_set_keymap('n', '#', [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
--vim.api.nvim_set_keymap('n', 'g*', [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
--vim.api.nvim_set_keymap('n', 'g#', [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)
--
--vim.api.nvim_set_keymap('n', '<Leader>l', '<Cmd>noh<CR>', kopts)


-- substitute
--vim.keymap.set("n", "s", require('substitute').operator, { noremap = true })
--vim.keymap.set("n", "ss", require('substitute').line, { noremap = true })
--vim.keymap.set("n", "S", require('substitute').eol, { noremap = true })
--vim.keymap.set("x", "s", require('substitute').visual, { noremap = true })


-- edge motion
vim.api.nvim_set_keymap('n', '<C-j>', '<Plug>(edgemotion-j)', {})
vim.api.nvim_set_keymap('n', '<C-k>', '<Plug>(edgemotion-k)', {})


-- lightmove
--vim.api.nvim_set_hl(0, 'LightspeedCursor', { reverse = true })
--vim.api.nvim_set_keymap('n', 'f', '<Plug>Lightspeed_s', { noremap = false, silent = true })
--vim.api.nvim_set_keymap('n', 'F', '<Plug>Lightspeed_S', { noremap = false, silent = true })
--vim.api.nvim_set_keymap('x', 'f', '<Plug>Lightspeed_s', { noremap = false, silent = true })
--vim.api.nvim_set_keymap('x', 'F', '<Plug>Lightspeed_S', { noremap = false, silent = true })

