return {
  'dnlhc/glance.nvim',
  cmd = 'Glance',
  keys = {
    { '<leader>ld', '<CMD>Glance definitions<CR>', desc = 'Glance Definitions' },
    { '<leader>lr', '<CMD>Glance references<CR>', desc = 'Glance References' },
    { '<leader>ly', '<CMD>Glance type_definitions<CR>', desc = 'Glance Type Definitions' },
    { '<leader>lm', '<CMD>Glance implementations<CR>', desc = 'Glance Implementations' },
  },
}
