return {
  'dnlhc/glance.nvim',
  event = 'VeryLazy',
  config = function()
    vim.keymap.set('n', '<leader>ld', '<CMD>Glance definitions<CR>')
    vim.keymap.set('n', '<leader>lr', '<CMD>Glance references<CR>')
    vim.keymap.set('n', '<leader>ly', '<CMD>Glance type_definitions<CR>')
    vim.keymap.set('n', '<leader>lm', '<CMD>Glance implementations<CR>')
  end,
}
