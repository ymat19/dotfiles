return {
  'sindrets/diffview.nvim',
  event = 'VeryLazy',
  config = function()
    vim.keymap.set('n', '<leader>dd', ':DiffviewOpen<CR>', { noremap = true, silent = true, desc = 'Diffview Open' })
    vim.keymap.set('n', '<leader>da', ':DiffviewOpen<CR> HEAD', { noremap = true, silent = true, desc = 'Git Diff All' })
    vim.keymap.set('n', '<leader>dc', ':DiffviewClose<CR>', { noremap = true, silent = true, desc = 'Git Diff All' })
  end,
}
