return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory' },
  keys = {
    { '<leader>dd', ':DiffviewOpen<CR>', noremap = true, silent = true, desc = 'Diffview Open' },
    { '<leader>da', ':DiffviewOpen HEAD<CR>', noremap = true, silent = true, desc = 'Git Diff All' },
    { '<leader>dc', ':DiffviewClose<CR>', noremap = true, silent = true, desc = 'Git Diff Close' },
  },
}
