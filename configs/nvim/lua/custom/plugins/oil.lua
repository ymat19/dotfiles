return {
  'stevearc/oil.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  opts = {
    default_file_explorer = true,
    columns = {
      'icon',
    },
    view_options = {
      show_hidden = true,
    },
    float = {
      padding = 2,
      max_width = math.floor(vim.o.columns * 0.9),
      max_height = math.floor(vim.o.lines * 0.9),
    },
    keymaps = {
      ['<C-v>'] = { 'actions.select', opts = { vertical = true } },
    },
  },
  keys = {
    {
      '<leader>e',
      function()
        require('oil').open_float()
      end,
      desc = 'Oil File Explorer',
    },
  },
}
