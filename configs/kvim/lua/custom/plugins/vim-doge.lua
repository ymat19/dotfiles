return {
  'kkoomen/vim-doge',
  event = 'VeryLazy',
  config = function()
    vim.api.nvim_create_user_command('DogeInstall', function()
      vim.fn['doge#install']()
    end, {})
    vim.keymap.set('n', '<Leader>ci', '<Plug>(doge-intall)', { desc = 'Doge Install' })
    vim.keymap.set('n', '<Leader>cg', '<Plug>(doge-generate)', { desc = 'Doge Generate' })
  end,
}
