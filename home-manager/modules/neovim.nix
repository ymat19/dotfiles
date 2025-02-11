{ config, pkgs, lib, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      tokyonight-nvim
      vim-airline
      hlchunk-nvim
      quick-scope
      substitute-nvim
      nvim-surround
      dial-nvim
      copilot-lua
    ];
    extraLuaConfig = builtins.readFile ../configs/init.lua;
  };

  home.packages = lib.mkAfter (with pkgs; [
    nixd
  ]);
}
