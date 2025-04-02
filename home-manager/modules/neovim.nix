{ config, pkgs, lib, __curPos, ... }:

let
  thisDir = builtins.dirOf __curPos.file;
  configDir = builtins.toPath "${thisDir}/../configs";
  kvimTargetDir = "${configDir}/nvim-kickstart";
  nvimTargetDir = "${configDir}/nvim";
  nvimHomeDir = "${config.home.homeDirectory}/.config/nvim";
  kvimHomeDir = "${config.home.homeDirectory}/.config/nvim-kickstart";
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
      # ui
      tokyonight-nvim
      # movement
      quick-scope
      clever-f-vim
      leap-nvim
      # util
      substitute-nvim
      nvim-surround
      plenary-nvim
    ];
    extraLuaConfig = builtins.readFile "${kvimTargetDir}/lua/custom/core.lua" + builtins.readFile "${nvimTargetDir}/init.lua";
  };

  home.packages = lib.mkAfter (with pkgs; [
    nixd

    # for copilot chat nvim
    lynx
    luajitPackages.tiktoken_core
    lua51Packages.luarocks
    mermaid-cli
    ghostscript_headless
  ]);

  home.file.${kvimHomeDir}.source = kvimTargetDir;
  home.file."${nvimHomeDir}/lua".source = nvimTargetDir;

  programs.zsh.initExtra = lib.mkAfter ''
    alias kvim='NVIM_APPNAME="nvim-kickstart" nvim'
  '';
}
