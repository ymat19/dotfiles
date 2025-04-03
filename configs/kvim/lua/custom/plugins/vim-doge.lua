return {
  'kkoomen/vim-doge',
  cmd = { 'DogeGenerate', 'DogeInstall' },
  config = function()
    vim.api.nvim_create_user_command('DogeInstall', function()
      vim.fn['doge#install']()
    end, {})
  end,
}
