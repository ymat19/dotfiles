-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
--vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  -- import your plugins
  "unblevable/quick-scope",
  --"wellle/targets.vim",
  --"gbprod/substitute.nvim",
  --"ggandor/lightspeed.nvim",
  --"monaqa/dial.nvim",
  --"kevinhwang91/nvim-hlslens",
  --"nvim-treesitter/nvim-treesitter",
  "haya14busa/vim-edgemotion",
  --{
  --  "kylechui/nvim-surround",
  --  version = "*", -- Use for stability; omit to use `main` branch for the latest features
  --  event = "VeryLazy",
  --  config = function()
  --      require("nvim-surround").setup({
  --          -- Configuration here, or leave empty to use defaults
  --      })
  --  end
  --},
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
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})

require("CopilotChat").setup {
  -- See Configuration section for options
      prompts = {
          Explain = {
              prompt = "/COPILOT_EXPLAIN 上記のコードを日本語で説明してください",
              description = "コードの説明をお願いする",
          },
          Review = {
              prompt = '/COPILOT_REVIEW 選択したコードをレビューしてください。レビューコメントは日本語でお願いします。',
              description = "コードのレビューをお願いする",
          },
          Fix = {
              prompt = "/COPILOT_FIX このコードには問題があります。バグを修正したコードを表示してください。説明は日本語でお願いします。",
              description = "コードの修正をお願いする",
          },
          Optimize = {
              prompt = "/COPILOT_REFACTOR 選択したコードを最適化し、パフォーマンスと可読性を向上させてください。説明は日本語でお願いします。",
              description = "コードの最適化をお願いする",
          },
          Docs = {
              prompt = "/COPILOT_GENERATE 選択したコードに関するドキュメントコメントを日本語で生成してください。",
              description = "コードのドキュメント作りをお願いする",
          },
          Tests = {
              prompt = "/COPILOT_TESTS 選択したコードの詳細なユニットテストを書いてください。説明は日本語でお願いします。",
              description = "コードのテストコード作成をお願いする",
          },
          FixDiagnostic = {
              prompt = 'コードの診断結果に従って問題を修正してください。修正内容の説明は日本語でお願いします。',
              description = "コードの静的解析結果に基づいた修正をお願いする",
              selection = require('CopilotChat.select').diagnostics,
          },
          Commit = {
              prompt =
              '変更に対するコミットメッセージを記述してください。 メッセージは日本語でお願いします。また、その結果に従って、ファイルをステージングしてコミットするためのgitコマンドも作成してください。',
              description = "コミットメッセージの作成をお願いする",
              selection = require('CopilotChat.select').gitdiff,
          },
          CommitStaged = {
              prompt =
              'ステージ済みの変更に対するコミットメッセージを記述してください。メッセージは日本語でお願いします。また、その結果に従って、コミットするためのgitコマンドも作成してください。',
              description = "ステージ済みのコミットメッセージの作成をお願いする",
              selection = function(source)
                  return require('CopilotChat.select').gitdiff(source, true)
              end,
          },
      },
}
