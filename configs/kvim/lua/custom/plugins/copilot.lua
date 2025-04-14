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
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    event = 'VeryLazy',
    dependencies = {
      { 'zbirenbaum/copilot.lua' },
      { 'nvim-lua/plenary.nvim', branch = 'master' }, -- for curl, log and async functions
    },
    build = 'make tiktoken', -- Only on MacOS or Linux
    opts = {
      -- sticky = { '日本語で話してください' },
      show_help = 'yes',
    },
    keys = {
      {
        '<leader>ac',
        function()
          vim.cmd 'CopilotChatOpen'
        end,
        desc = 'OPEN CHAT',
      },
    },
    config = function()
      require('CopilotChat').setup {
        -- https://qiita.com/haw_ohnuma/items/1ec8ef5091b440cbb8bd
        prompts = {
          Explain = {
            prompt = '/COPILOT_EXPLAIN コードを日本語で説明してください',
            mapping = '<leader>ae',
            description = 'EXPLAIN',
          },
          Review = {
            prompt = '/COPILOT_REVIEW コードを日本語でレビューしてください。',
            mapping = '<leader>ar',
            description = 'REVIEW',
          },
          Fix = {
            prompt = '/COPILOT_FIX このコードには問題があります。バグを修正したコードを表示してください。説明は日本語でお願いします。',
            mapping = '<leader>af',
            description = 'FIX',
          },
          Optimize = {
            prompt = '/COPILOT_REFACTOR 選択したコードを最適化し、パフォーマンスと可読性を向上させてください。説明は日本語でお願いします。',
            mapping = '<leader>ao',
            description = 'REFACTOR',
          },
          Docs = {
            prompt = '/COPILOT_GENERATE 選択したコードに関するドキュメントコメントを日本語で生成してください。',
            mapping = '<leader>ad',
            description = 'GENERATE',
          },
          Tests = {
            prompt = '/COPILOT_TESTS 選択したコードの詳細なユニットテストを書いてください。説明は日本語でお願いします。',
            mapping = '<leader>at',
            description = 'TESTS',
          },
          FixDiagnostic = {
            prompt = 'コードの診断結果に従って問題を修正してください。修正内容の説明は日本語でお願いします。',
            mapping = '<leader>ad',
            description = 'DIAGNOSTICS',
            selection = require('CopilotChat.select').diagnostics,
          },
          Commit = {
            prompt = '実装差分に対するコミットメッセージを日本語で記述してください。',
            mapping = '<leader>am',
            description = 'MESSAGE DIFF',
            selection = require('CopilotChat.select').gitdiff,
          },
          CommitStaged = {
            prompt = 'ステージ済みの変更に対するコミットメッセージを日本語で記述してください。',
            mapping = '<leader>as',
            description = 'MESSAGE STAGING',
            selection = function(source)
              return require('CopilotChat.select').gitdiff(source, true)
            end,
          },
        },
      }
    end,
  },
}
