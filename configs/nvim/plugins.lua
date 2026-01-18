vim.lsp.config.nixd = {
	cmd = { 'nixd' },
	filetypes = { 'nix' },
	root_markers = { 'flake.nix', '.git' },
}

vim.api.nvim_create_autocmd('FileType', {
	pattern = 'nix',
	callback = function(args)
		vim.lsp.enable('nixd', args.buf)
	end,
})

-- treesitter (Neovim 0.10+ built-in API)
vim.api.nvim_create_autocmd('FileType', {
	callback = function()
		pcall(vim.treesitter.start)
	end,
})
vim.api.nvim_create_autocmd('FileType', {
	callback = function()
		if pcall(vim.treesitter.language.get_lang, vim.bo.filetype) then
			vim.bo.indentexpr = "v:lua.vim.treesitter.indentexpr()"
		end
	end,
})

vim.cmd([[colorscheme tokyonight]])

-- quick scope https://zenn.dev/neo/scraps/49266fed7ce6b6
vim.cmd([[highlight QuickScopePrimary guifg='#afff5f' gui=underline ctermfg=155 cterm=underline]])
vim.cmd([[highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline]])
