-- general settings
vim.opt.number = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true  -- デフォルトで大文字・小文字を無視
vim.opt.smartcase = true   -- 大文字が含まれる場合は大文字・小文字を区別
vim.opt.scrolloff = 5
vim.o.expandtab = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true
vim.opt.clipboard:append({ "unnamed", "unnamedplus" })

-- key bindings
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', 'jk', '<ESC>:w<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-j>', '5j', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-k>', '5k', { noremap = true, silent = true })
vim.api.nvim_set_keymap('x', '<C-j>', '5j', { noremap = true, silent = true })
vim.api.nvim_set_keymap('x', '<C-k>', '5k', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<CR>', ':nohlsearch<CR>', { noremap = true, silent = true })
--vim.api.nvim_set_keymap('n', 's', '"_diwP', { noremap = true, silent = true })
--vim.api.nvim_set_keymap('n', 'S', '"_diWP', { noremap = true, silent = true })
--vim.api.nvim_set_keymap('n', '<C-h>', '^', { noremap = true, silent = true })
--vim.api.nvim_set_keymap('n', '<C-l>', '$', { noremap = true, silent = true })


-- plugins setup
require'substitute'.setup{}
require'nvim-surround'.setup{}
vim.api.nvim_del_keymap('v', 'S')
require('leap').create_default_mappings()
require'lspconfig'.nixd.setup{}
require("hardtime").setup()
require('neoscroll').setup({ mappings = {'<C-u>', '<C-d>'} })
require'hlchunk'.setup{
    chunk = {
        enable = true
    }
}

local parser_path = vim.fn.stdpath("data") .. "/treesitter"
vim.opt.runtimepath:prepend(parser_path)
require'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all" (the listed parsers MUST always be installed)
  -- ensure_installed = { "nix", "lua", "c_sharp", "python", "markdown", "markdown_inline", "json", "yaml", "toml", "html", "css", "javascript", "typescript", "tsx", "bash" },
  parser_install_dir = parser_path,
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
  },
  textsubjects = {
    enable = true,
    --keymaps = {},
    prev_selection = ',',
    keymaps = {
        ['.'] = 'textsubjects-smart',
        [';'] = 'textsubjects-container-outer',
        ['i;'] = 'textsubjects-container-inner',
    },
  }
}

require("oil").setup()
vim.keymap.set("n", "-", "<CMD>vs<CR><CMD>Oil<CR>", { desc = "Open parent directory" })
vim.keymap.set("n", "_", "<CMD>vnew<CR><CMD>Oil<CR>", { desc = "Open parent directory" })

vim.cmd[[colorscheme tokyonight]]

-- https://zenn.dev/neo/scraps/49266fed7ce6b6
vim.cmd[[highlight QuickScopePrimary guifg='#afff5f' gui=underline ctermfg=155 cterm=underline]]
vim.cmd[[highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline]]

-- substitute-nvim
vim.keymap.set("n", "r", require('substitute').operator, { noremap = true })
vim.api.nvim_set_keymap('n', 'rr', 'r', { noremap = true, silent = true })
vim.keymap.set("n", "R", require('substitute').eol, { noremap = true })
vim.keymap.set("x", "r", require('substitute').visual, { noremap = true })

-- clever-f
vim.g.clever_f_smart_case = 1
vim.g.clever_f_fix_key_direction = 1
vim.g.clever_f_chars_match_any_signs = ";"

-- lazy setup
--vim.api.nvim_create_autocmd("InsertEnter", {
--    pattern = "*",
--    callback = function()
--      require('copilot').setup({
--        suggestion = {
--          auto_trigger = true,
--          keymap = {
--            accept = "<Tab>",
--            next = "<Down>",
--            prev = "<Up>",
--          }
--        }
--      })
--    end
--})
-- lazy setup
--vim.api.nvim_create_autocmd("VimEnter", {
--    pattern = "*",
--    callback = function()
--      require('CopilotChat').setup{}
--    end
--})

