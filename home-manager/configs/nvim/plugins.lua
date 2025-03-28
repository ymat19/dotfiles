require("lspconfig").nixd.setup({})

-- treesitter
require("nvim-treesitter.configs").setup({
	highlight = {
		enable = true,
	},
	indent = {
		enable = true,
	},
})

vim.cmd([[colorscheme tokyonight]])

-- quick scope https://zenn.dev/neo/scraps/49266fed7ce6b6
vim.cmd([[highlight QuickScopePrimary guifg='#afff5f' gui=underline ctermfg=155 cterm=underline]])
vim.cmd([[highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline]])
