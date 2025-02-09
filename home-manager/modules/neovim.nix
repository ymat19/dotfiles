{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      vim-airline
      quick-scope
      nvim-lspconfig
    ];
    extraLuaConfig = ''
      --vim.g.mapleader = ' '
      vim.api.nvim_set_keymap('i', 'jj', '<ESC>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('i', 'jk', '<ESC>:w<CR>', { noremap = true, silent = true })
      vim.opt.clipboard:append({ "unnamed", "unnamedplus" })
      vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', 's', '"_diwP', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', 'S', '"_diWP', { noremap = true, silent = true })
      vim.opt.hlsearch = true
      vim.api.nvim_set_keymap('n', '<CR>', ':nohlsearch<CR>', { noremap = true, silent = true })
      vim.opt.ignorecase = true  -- デフォルトで大文字・小文字を無視
      vim.opt.smartcase = true   -- 大文字が含まれる場合は大文字・小文字を区別
      --vim.api.nvim_set_keymap('n', '<C-h>', '^', { noremap = true, silent = true })
      --vim.api.nvim_set_keymap('n', '<C-l>', '$', { noremap = true, silent = true })
      vim.o.expandtab = true
      vim.o.tabstop = 2
      vim.o.shiftwidth = 2
      vim.o.expandtab = true

      require'lspconfig'.nixd.setup{}
    '';
  };
}
