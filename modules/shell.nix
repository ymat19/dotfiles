{ config, pkgs, lib, ... }:

{
  # SSH先でxterm-kittyのterminfoが見つからない問題を防ぐ
  home.packages = [ pkgs.kitty.terminfo ];
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    #autosuggestion.highlight = "fg=#ff00ff,bg=cyan,bold,underline";
    syntaxHighlighting.enable = true;
    initContent = ''
      export TERMINFO_DIRS="${pkgs.kitty.terminfo}/share/terminfo''${TERMINFO_DIRS:+:$TERMINFO_DIRS}"
    '' + builtins.readFile ../configs/zshrc;
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      export TERMINFO_DIRS="${pkgs.kitty.terminfo}/share/terminfo''${TERMINFO_DIRS:+:$TERMINFO_DIRS}"
    '';
  };

  #powerline-go
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
