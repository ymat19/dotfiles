{ config, pkgs, lib, ... }:

{
  home.packages = lib.mkAfter (with pkgs; [
    asdf-vm
  ]);

  programs.bash.initExtra = lib.mkAfter ''
    . "${pkgs.asdf-vm}/share/asdf-vm/asdf.sh"
    . "${pkgs.asdf-vm}/share/asdf-vm/completions/asdf.bash"
  '';

  programs.zsh.initExtra = lib.mkAfter ''
    . "${pkgs.asdf-vm}/share/asdf-vm/asdf.sh"
    autoload -Uz bashcompinit && bashcompinit
    . "${pkgs.asdf-vm}/share/asdf-vm/completions/asdf.bash"
  '';
}
