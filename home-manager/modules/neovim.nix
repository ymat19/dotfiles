{ config, pkgs, lib, __curPos, ... }:

let
  thisDir = builtins.dirOf __curPos.file;
  kvimTargetDir = builtins.toPath "${thisDir}/../configs/nvim-kickstart";
  kvimLinkDir = "${config.home.homeDirectory}/.config/nvim-kickstart";
in
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      # essentials
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      # buffer
      oil-nvim
      vim-startify
      # ui
      tokyonight-nvim
      vim-airline
      # movement
      quick-scope
      clever-f-vim
      neoscroll-nvim
      hardtime-nvim
      leap-nvim
      # visual
      vim-expand-region
      # util
      substitute-nvim
      nvim-surround
      dial-nvim
      plenary-nvim
    ];
    extraLuaConfig = builtins.readFile ../configs/init.lua;
  };

  home.packages = lib.mkAfter (with pkgs; [
    nixd
  ]);

  home.file.${kvimLinkDir}.source = kvimTargetDir;

  programs.zsh.initExtra = lib.mkAfter ''
    alias kvim='NVIM_APPNAME="nvim-kickstart" nvim'
  '';
}
