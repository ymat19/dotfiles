return {
  {
    'zbirenbaum/copilot.lua',
    event = 'VeryLazy',
    config = function()
      require('copilot').setup {
        suggestion = { enabled = false },
        panel = { enabled = false },
      }
    end,
  },
  {
    'zbirenbaum/copilot-cmp',
    event = 'VeryLazy',
    dependencies = {
      { 'zbirenbaum/copilot.lua' },
    },
    config = function()
      require('copilot_cmp').setup()
    end,
  },
}
