return {
  'folke/sidekick.nvim',
  dependencies = { 'folke/snacks.nvim' },
  opts = {
    cli = {
      mux = {
        backend = 'tmux',
        enabled = true,
        create = 'split',
      },
    },
  },
  keys = {
    { '<leader>a', nil, desc = 'AI/Sidekick' },
    -- CLI toggle
    {
      '<leader>aa',
      function()
        require('sidekick.cli').toggle()
      end,
      desc = 'Toggle Sidekick',
      mode = { 'n', 't' },
    },
    {
      '<leader>ac',
      function()
        require('sidekick.cli').toggle { name = 'claude', focus = true }
      end,
      desc = 'Toggle Claude',
      mode = { 'n', 't' },
    },
    {
      '<leader>ao',
      function()
        require('sidekick.cli').toggle { name = 'codex', focus = true }
      end,
      desc = 'Toggle Codex',
      mode = { 'n', 't' },
    },
    -- Tool select / disconnect
    {
      '<leader>as',
      function()
        require('sidekick.cli').select()
      end,
      desc = 'Select tool',
    },
    {
      '<leader>ad',
      function()
        require('sidekick.cli').close()
      end,
      desc = 'Disconnect session',
    },
    -- Send context
    {
      '<leader>at',
      function()
        require('sidekick.cli').send { msg = '{this}' }
      end,
      desc = 'Send word/selection',
      mode = { 'n', 'x' },
    },
    {
      '<leader>af',
      function()
        require('sidekick.cli').send { msg = '{file}' }
      end,
      desc = 'Send file',
    },
    -- Prompts
    {
      '<leader>ap',
      function()
        require('sidekick.cli').prompt()
      end,
      desc = 'Prompt picker',
      mode = { 'n', 'x' },
    },
    -- NES (Next Edit Suggestions)
    {
      '<tab>',
      function()
        if not require('sidekick').nes_jump_or_apply() then
          return '<Tab>'
        end
      end,
      expr = true,
      desc = 'NES: Jump/Apply',
    },
  },
}
