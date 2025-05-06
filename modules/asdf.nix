{ config, pkgs, lib, onNixOS, ... }:

# NixOSでは制約から、asdfを使えない
(if onNixOS then { } else {
  home.packages = lib.mkAfter (with pkgs; [
    asdf-vm
  ]);

  programs.bash.bashrcExtra = lib.mkAfter ''
    export PATH="''${ASDF_DATA_DIR:-''$HOME/.asdf}/shims:''$PATH"
  '';

  programs.zsh.initExtra = lib.mkAfter ''
    export PATH="''${ASDF_DATA_DIR:-''$HOME/.asdf}/shims:''$PATH"
  '';
})
