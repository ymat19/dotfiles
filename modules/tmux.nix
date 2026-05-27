{ config, pkgs, ... }:

let
  tmux-agent-sidebar-version = "0.10.1";

  tmux-agent-sidebar-src = pkgs.fetchFromGitHub {
    owner = "hiroppy";
    repo = "tmux-agent-sidebar";
    rev = "v${tmux-agent-sidebar-version}";
    sha256 = "1bkhnxb9sw9r1vmby2dxf3hrzpsy3a90jmcxykf709rdzjh9wm1q";
  };

  tmux-agent-sidebar-bin = pkgs.fetchurl {
    url =
      let
        asset =
          if pkgs.stdenv.isDarwin then
            (if pkgs.stdenv.isAarch64 then "tmux-agent-sidebar-darwin-aarch64" else "tmux-agent-sidebar-darwin-x86_64")
          else
            (if pkgs.stdenv.isAarch64 then "tmux-agent-sidebar-linux-aarch64" else "tmux-agent-sidebar-linux-x86_64");
      in
      "https://github.com/hiroppy/tmux-agent-sidebar/releases/download/v${tmux-agent-sidebar-version}/${asset}";
    sha256 =
      if pkgs.stdenv.isDarwin then
        (if pkgs.stdenv.isAarch64 then
          "0d41jy6m74xjzfjp5q4ar3z1798v93rygcxc0ks3xqwwx3g4066b"
        else
          "1xjyl8fpyv5xlv9rjkvh3g7v5hdh4a3nhc1wcd8kld1bjsf7lc97")
      else
        (if pkgs.stdenv.isAarch64 then
          "177ykxh3ic9088kjsfwnd2h4gma1lsgbwzx9yj68hbgl01l8qbh8"
        else
          "1my9czk10irsc1vbdrlqh4j50b1yjl743s73inp73v37jzjjwm48");
  };

  tmux-agent-sidebar-plugin = pkgs.runCommand "tmux-agent-sidebar-${tmux-agent-sidebar-version}" { } ''
    cp -r ${tmux-agent-sidebar-src} $out
    chmod -R +w $out
    mkdir -p $out/bin
    cp ${tmux-agent-sidebar-bin} $out/bin/tmux-agent-sidebar
    chmod +x $out/bin/tmux-agent-sidebar
  '';

  tpm-src = pkgs.fetchFromGitHub {
    owner = "tmux-plugins";
    repo = "tpm";
    rev = "v3.1.0";
    sha256 = "18i499hhxly1r2bnqp9wssh0p1v391cxf10aydxaa7mdmrd3vqh9";
  };
in
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    mouse = true;
    customPaneNavigationAndResize = true;
    shell = "${pkgs.zsh}/bin/zsh";
    extraConfig = builtins.readFile ../configs/tmux.conf;
    plugins = with pkgs.tmuxPlugins; [
      #tmux-resurrect
      #tmux-continuum
      #tmux-sensible
      #tmux-prefix-highlight
      #tmux-copycat
      sensible
      logging
      {
        plugin = tokyo-night-tmux;
        extraConfig = ''
### Tokyo Night Theme configuration
set -g @tokyo-night-tmux_show_hostname 1
set -g @tokyo-night-tmux_transparent 1
set -g @tokyo-night-tmux_show_path 1
set -g @tokyo-night-tmux_path_format relative # 'relative' or 'full'
set -g @tokyo-night-tmux_show_git 0
set -g @tokyo-night-tmux_show_wbg 0
        '';
      }
    ];
  };

  # TPM (tmux plugin manager) - declarative install
  # home-manager's programs.tmux uses XDG path: ~/.config/tmux/plugins/
  xdg.configFile."tmux/plugins/tpm".source = tpm-src;

  # tmux-agent-sidebar plugin (source + pre-built binary)
  xdg.configFile."tmux/plugins/tmux-agent-sidebar".source = tmux-agent-sidebar-plugin;

  # prefix+J/K で呼ぶ "sidebar 並び順を再現してエージェントペインを cycle" スクリプト
  xdg.configFile."tmux/cycle-agent.sh" = {
    source = ../configs/tmux-cycle-agent.sh;
    executable = true;
  };
}
