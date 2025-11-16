{ pkgs, lib, username, homeDirectory, onNixOS, envName ? "", ... }:

let
  # NixOS rebuild script for current environment
  nixos-rebuild-current = pkgs.writeShellScriptBin "nixos-rebuild-current" (
    builtins.replaceStrings
      [ "@homeDirectory@" "@envName@" "@libnotify@" ]
      [ homeDirectory envName "${pkgs.libnotify}" ]
      (builtins.readFile ../../scripts/nixos-rebuild-current.sh)
  );

  # Script to dynamically run scripts from ~/.config/hypr/scripts/
  run-hypr-script = pkgs.writeShellScriptBin "run-hypr-script" (
    builtins.replaceStrings
      [ "@homeDirectory@" "@libnotify@" "@rofi@" ]
      [ homeDirectory "${pkgs.libnotify}" "${pkgs.rofi}" ]
      (builtins.readFile ../../scripts/run-hypr-script.sh)
  );

  # Restart xremap service
  restart-xremap = pkgs.writeShellScriptBin "restart-xremap" (
    builtins.replaceStrings
      [ "@libnotify@" ]
      [ "${pkgs.libnotify}" ]
      (builtins.readFile ../../scripts/restart-xremap.sh)
  );
in
{
  home.packages = [
    nixos-rebuild-current
    run-hypr-script
    restart-xremap
  ];

  home.file = {
    ".config/hypr/scripts/nixos-rebuild".source = "${nixos-rebuild-current}/bin/nixos-rebuild-current";
    ".config/hypr/scripts/restart-xremap".source = "${restart-xremap}/bin/restart-xremap";
  };
}
