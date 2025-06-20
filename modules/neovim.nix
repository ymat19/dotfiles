{ config, pkgs, lib, __curPos, ... }:

let
  thisDir = builtins.dirOf __curPos.file;
  configDir = builtins.toPath "${thisDir}/../configs";
  kvimTargetDir = "${configDir}/kvim";
  nvimTargetDir = "${configDir}/nvim";
  nvimHomeDir = "${config.home.homeDirectory}/.config/nvim";
  kvimHomeDir = "${config.home.homeDirectory}/.config/kvim";
  nvimPy = pkgs.python313.withPackages (ps: [ ps.pynvim ]);
  nvimNode = pkgs.nodejs_24;
in
{
  home.packages = lib.mkAfter (with pkgs; [
    nixd

    # for copilot chat nvim
    lynx
    luajitPackages.tiktoken_core
    lua51Packages.luarocks
    mermaid-cli
    ghostscript_headless
    # for nil
    cargo
  ]);

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    plugins = with pkgs.vimPlugins; [
      # essentials
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      plenary-nvim
      # ui
      tokyonight-nvim
      # movement
      quick-scope
      clever-f-vim
      leap-nvim
      # util
      substitute-nvim
      nvim-surround
      dial-nvim
    ];
    extraLuaConfig = builtins.readFile "${kvimTargetDir}/lua/custom/core.lua" + builtins.readFile "${nvimTargetDir}/init.lua" +
      ''
        vim.g.python3_host_prog = "${nvimPy}/bin/python3"
      '';
    extraPackages = [ nvimNode ];
    extraWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      "${nvimNode}/bin"
      "--prefix"
      "PATH"
      ":"
      "${nvimPy}/bin"
    ];
  };

  home.file.${kvimHomeDir}.source = kvimTargetDir;
  home.file."${nvimHomeDir}/lua".source = nvimTargetDir;

  home.shellAliases = lib.mkAfter {
    kvim = "NVIM_APPNAME=kvim nvim";
  };
}
