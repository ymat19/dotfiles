-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Example configs: https://github.com/LunarVim/starter.lvim
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

-- common key binds
lvim.keys.insert_mode['jj'] = "<ESC>"
lvim.keys.insert_mode['jk'] = "<ESC>:w<CR>"
lvim.keys.normal_mode["<C-h>"] = false
lvim.keys.normal_mode["<C-j>"] = false
lvim.keys.normal_mode["<C-k>"] = false
lvim.keys.normal_mode["<C-l>"] = false
lvim.keys.normal_mode["L"] = ":bnext<CR>"
lvim.keys.normal_mode["H"] = ":bprev<CR>"
lvim.builtin.terminal.open_mapping = "<c-t>"
lvim.builtin.cmp.mapping["<Tab>"] = lvim.builtin.cmp.mapping["<CR>"]
lvim.builtin.cmp.mapping["<Right>"] = lvim.builtin.cmp.mapping["<CR>"]

-- install plugins
lvim.plugins = {
  "ChristianChiarulli/swenv.nvim",
  "stevearc/dressing.nvim",
  "mfussenegger/nvim-dap-python",
  "nvim-neotest/neotest",
  "nvim-neotest/neotest-python",

  -- copilot系
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({})
    end,
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" }, -- or github/copilot.vim
      { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
    },
    build = "make tiktoken", -- Only on MacOS or Linux
    opts = {
      debug = true, -- Enable debugging
      -- See Configuration section for rest
    },
  },

}


-- cpilot settings
table.insert(lvim.plugins, {
  "zbirenbaum/copilot-cmp",
  event = "InsertEnter",
  dependencies = { "zbirenbaum/copilot.lua" },
  config = function()
    vim.defer_fn(function()
      require("copilot").setup() -- https://github.com/zbirenbaum/copilot.lua/blob/master/README.md#setup-and-configuration
      require("copilot_cmp").setup() -- https://github.com/zbirenbaum/copilot-cmp/blob/master/README.md#configuration
    end, 100)
  end,
})
-- 規定のプロンプトを上書き
require("CopilotChat").setup({
    debug = true,
    prompts = {
        Explain = {
            prompt = "/COPILOT_EXPLAIN 上記のコードを日本語で説明してください",
            description = "バディにコードの説明をお願いする",
        },
        Review = {
            prompt = '/COPILOT_REVIEW 選択したコードをレビューしてください。レビューコメントは日本語でお願いします。',
            description = "バディにコードのレビューをお願いする",
        },
        Fix = {
            prompt = "/COPILOT_FIX このコードには問題があります。バグを修正したコードを表示してください。説明は日本語でお願いします。",
            description = "バディにコードの修正をお願いする",
        },
        Optimize = {
            prompt = "/COPILOT_REFACTOR 選択したコードを最適化し、パフォーマンスと可読性を向上させてください。説明は日本語でお願いします。",
            description = "バディにコードの最適化をお願いする",
        },
        Docs = {
            prompt = "/COPILOT_GENERATE 選択したコードに関するドキュメントコメントを日本語で生成してください。",
            description = "バディにコードのドキュメント作りをお願いする",
        },
        Tests = {
            prompt = "/COPILOT_TESTS 選択したコードの詳細なユニットテストを書いてください。説明は日本語でお願いします。",
            description = "バディにコードのテストコード作成をお願いする",
        },
        FixDiagnostic = {
            prompt = 'コードの診断結果に従って問題を修正してください。修正内容の説明は日本語でお願いします。',
            description = "バディにコードの静的解析結果に基づいた修正をお願いする",
            selection = require('CopilotChat.select').diagnostics,
        },
        Commit = {
            prompt =
            'commitize の規則に従って、変更に対するコミットメッセージを記述してください。 タイトルは最大50文字で、メッセージは72文字で折り返されるようにしてください。 メッセージ全体を gitcommit 言語のコード ブロックでラップしてください。メッセージは日本語でお願いします。',
            description = "バディにコミットメッセージの作成をお願いする",
            selection = require('CopilotChat.select').gitdiff,
        },
        CommitStaged = {
            prompt =
            'commitize の規則に従って、ステージ済みの変更に対するコミットメッセージを記述してください。 タイトルは最大50文字で、メッセージは72文字で折り返されるようにしてください。 メッセージ全体を gitcommit 言語のコード ブロックでラップしてください。メッセージは日本語でお願いします。',
            description = "バディにステージ済みのコミットメッセージの作成をお願いする",
            selection = function(source)
                return require('CopilotChat.select').gitdiff(source, true)
            end,
        },
    },
})

-- bufferの内容を元にチャットを開く
function CopilotChatBuffer()
  local input = vim.fn.input("Quick Chat: ")
  if input ~= "" then
    require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
  end
end

-- telescope を使ってアクションプロンプトを表示する
function ShowCopilotChatActionPrompt()
  local actions = require("CopilotChat.actions")
  require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
end

-- 一般的な質問をする
function CopilotGeneralQuestion()
  local input = vim.fn.input("Ask Copilot: ")
  if input ~= "" then
    require("CopilotChat").ask(input)
  end
end

-- which_keyに追加
lvim.builtin.which_key.mappings["o"] = {
  name = "Copilot",
  -- <leader>ob でCopilotとBufferに基づいたチャットを開く
  b = { "<cmd>lua CopilotChatBuffer()<CR>", "Open Copilot Chat by Buffer" },
  -- <leader>ot  でtelescopeを用いたアクションプロンプトを表示する
  t = { "<cmd>lua ShowCopilotChatActionPrompt()<CR>", "Show Copilot Chat Action Prompt" },
  -- <leader>os でCopilotの設定を開く
  s = { "<cmd>edit ~/.config/lvim/config.lua<CR>", "Open Copilot Settings" },
  -- <leader>oq で一般的な質問をする
  q = { "<cmd>lua CopilotGeneralQuestion()<CR>", "Ask General Question" },
  -- <leader>ol でCopilotのログを表示する
  l = { "<cmd>Copilot status<CR>", "Show Copilot Status" },
  -- <leader>oc でCopilotのステータスを表示する
  c = { "<cmd>Copilot panel<CR>", "Show Copilot Panel" },
}


-- python settings
-- automatically install python syntax highlighting
lvim.builtin.treesitter.ensure_installed = {
  "python",
}

-- setup formatting
local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup { { name = "black" }, }
lvim.format_on_save.enabled = true
lvim.format_on_save.pattern = { "*.py" }

-- setup linting
local linters = require "lvim.lsp.null-ls.linters"
linters.setup { { command = "flake8", filetypes = { "python" } } }

