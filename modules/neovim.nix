{
  config,
  pkgs,
  lib,
  __curPos,
  ...
}:

let
  thisDir = builtins.dirOf __curPos.file;
  configDir = builtins.toPath "${thisDir}/../configs";
  nvimTargetDir = "${configDir}/nvim";
  nvimHomeDir = "${config.home.homeDirectory}/.config/nvim";
  nvimPy = pkgs.python313.withPackages (ps: [ ps.pynvim ]);
  nvimNode = pkgs.nodejs_24;
in
{
  home.packages = lib.mkAfter (
    with pkgs;
    [
      nixd

      # for nil
      cargo
    ]
  );

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    plugins = [ ];
    initLua = builtins.readFile "${nvimTargetDir}/init.lua" + ''
      vim.g.python3_host_prog = "${nvimPy}/bin/python3"
    '';
    extraPackages = [
      nvimNode
      pkgs.gcc
    ];
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

  home.file."${nvimHomeDir}/lua".source = "${nvimTargetDir}/lua";
}
