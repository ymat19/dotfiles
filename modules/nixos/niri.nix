{ config, pkgs, lib, envName, inputs, ... }:

{
  home.packages = with pkgs; [
    waypaper
    mpvpaper
    adwaita-qt
    adwaita-qt6
    hypridle
    grim
    slurp
    satty
    xwayland-satellite
    inputs.niri-scratchpad.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        lock_cmd = "hyprlock";
      };

      listener = [
        {
          timeout = 2100;
          on-timeout = "hyprlock";
        }
        {
          timeout = 5400;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };


  # Niri KDL設定ファイル（envName別に動的生成）
  xdg.configFile."niri/config.kdl" = let
    baseConfig = builtins.readFile ../../configs/niri-base.kdl;
    resizeScript = "${config.xdg.configHome}/niri/niri-resize-scratch.sh";

    # Air専用キーバインドを既存のbindsブロック内に追加
    airKeybinds = lib.optionalString (envName == "air") ''
    // Air (Apple Silicon) specific keybinds
    Mod+Z { spawn-sh "niri msg output eDP-1 scale 1.0666667 && ${resizeScript}"; }
    Mod+Shift+Z { spawn-sh "niri msg output eDP-1 scale 1.0 && ${resizeScript}"; }
    Mod+I { spawn "niri" "msg" "input" "device" "apple-mtp-multi-touch" "enabled" "true"; }
    Mod+Shift+I { spawn "niri" "msg" "input" "device" "apple-mtp-multi-touch" "enabled" "false"; }
'';

    # Dyna専用キーバインドを既存のbindsブロック内に追加
    dynaKeybinds = lib.optionalString (envName == "dyna") ''
    // Dyna specific keybinds
    Mod+Z { spawn-sh "niri msg output DP-1 mode 1920x1080@60 && ${resizeScript}"; }
    Mod+Shift+Z { spawn-sh "niri msg output DP-1 mode 3440x1440@59.999 && ${resizeScript}"; }
'';

    # bindsブロック内の「Media keys」直前に環境別キーバインドを挿入
    envKeybinds = if envName == "air" then airKeybinds
      else if envName == "dyna" then dynaKeybinds
      else "";

    configWithEnvBinds = if envKeybinds != "" then
      builtins.replaceStrings
        ["    // Quit\n    Mod+Shift+C { quit; }\n\n    // Media keys"]
        ["    // Quit\n    Mod+Shift+C { quit; }\n\n${envKeybinds}    // Media keys"]
        baseConfig
    else baseConfig;

    # Air専用の出力設定を追加
    airOutput = lib.optionalString (envName == "air") ''

// Air specific: internal display config
output "eDP-1" {
    mode "2560x1600@60"
    scale 1.0666667
}
'';

    # Dyna専用の出力設定を追加
    dynaOutput = lib.optionalString (envName == "dyna") ''

// Dyna specific: disable internal display
output "eDP-1" {
    off
}
'';
  in {
    text = configWithEnvBinds + airOutput + dynaOutput;
  };

  # Scratchpad resize script
  xdg.configFile."niri/niri-resize-scratch.sh" = {
    source = ../../configs/niri-resize-scratch.sh;
    executable = true;
  };

  # GTK/Qt設定（hyprland.nixから継承）
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Adwaita";
    size = 24;
    package = pkgs.adwaita-icon-theme;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  # Fcitx5設定（hyprland.nixと同じ）
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-mozc qt6Packages.fcitx5-configtool ];
  };

  home.sessionVariables = lib.mkAfter
    ({
      XMODIFIERS = "@im=fcitx";
      INPUT_METHOD = "fcitx";
      WLR_EGL_NO_MODIFIERS = "1"; # NVIDIA 用
      LIBVA_DRIVER_NAME = "nvidia";
      XDG_SESSION_TYPE = "wayland";
      GTK_THEME = "Adwaita-dark";
      QT_STYLE_OVERRIDE = "adwaita-dark";
    });

  # https://zenn.dev/watagame/articles/hyprland-nix
  programs.hyprlock = {
    enable = true;
    settings = {
      background = {
        monitor = "";
        #path = "${pkgs.wallpaper-springcity}/wall.png";
        blur_passes = 2;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };

      general = {
        no_fade_in = false;
        grace = 0;
        disable_loading_bar = false;
      };

      label = [
        # Yar
        {
          monitor = "";
          text = ''
            						cmd[update:1000] echo -e "$(date +"%Y")"
            					'';
          color = "rgba(216, 222, 233, 0.70)";
          font_size = 90;
          font_family = "SF Pro Display Bold";
          position = "0, 350";
          halign = "center";
          valign = "center";
        }
        # Date-Month
        {
          monitor = "";
          text = ''
            						cmd[update:1000] echo -e "$(date +"%m/%d")"
            					'';
          color = "rgba(216, 222, 233, 0.70)";
          font_size = 40;
          font_family = "SF Pro Display Bold";
          position = "0, 250";
          halign = "center";
          valign = "center";
        }
        # Time
        {
          monitor = "";
          text = ''
            						cmd[update:1000] echo "<span>$(date +"- %H:%M -")</span>"
            					'';
          color = "rgba(216, 222, 233, 0.70)";
          font_size = 20;
          font_family = "SF Pro Display Bold";
          position = "0, 190";
          halign = "center";
          valign = "center";
        }

        # User
        {
          monitor = "";
          text = "    $USER";
          color = "rgba(216, 222, 233, 0.80)";
          outline_thickness = 2;
          dots_size = 0.2; # Scale of input-field height, 0.2 - 0.8
          dots_spacing = 0.2; # Scale of dots' absolute size, 0.0 - 1.0
          dots_center = true;
          font_size = 18;
          font_family = "SF Pro Display Bold";
          position = "0, -130";
          halign = "center";
          valign = "center";
        }

        # Power
        {
          monitor = "";
          text = "󰐥  󰜉  󰤄";
          color = "rgba(255, 255, 255, 0.6)";
          font_size = 50;
          position = "0, 100";
          halign = "center";
          valign = "bottom";
        }
      ];

      # Profile-Photo
      image = {
        monitor = "";
        path = "${pkgs.nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png";
        border_size = 2;
        border_color = "rgba(255, 255, 255, .65)";
        size = 130;
        rounding = -1;
        rotate = 0;
        reload_time = -1;
        reload_cmd = "";
        position = "0, 40";
        halign = "center";
        valign = "center";
      };

      # User box
      shape = {
        monitor = "";
        size = "300, 60";
        color = "rgba(255, 255, 255, .1)";
        rounding = -1;
        border_size = 0;
        border_color = "rgba(255, 255, 255, 0)";
        rotate = 0;
        xray = false; # if true, make a "hole" in the background (rectangle of specified size, no rotation)
        position = "0, -130";
        halign = "center";
        valign = "center";
      };

      # INPUT FIELD
      input-field = {
        monitor = "";
        size = "300, 60";
        outline_thickness = 2;
        dots_size = 0.2; # Scale of input-field height, 0.2 - 0.8
        dots_spacing = 0.2; # Scale of dots' absolute size, 0.0 - 1.0
        dots_center = true;
        outer_color = "rgba(255, 255, 255, 0)";
        inner_color = "rgba(255, 255, 255, 0.1)";
        font_color = "rgb(200, 200, 200)";
        fade_on_empty = false;
        font_family = "SF Pro Display Bold";
        placeholder_text = "<i><span foreground='##ffffff99'>🔒 Enter Pass</span></i>";
        hide_input = false;
        position = "0, -210";
        halign = "center";
        valign = "center";
      };
    };
  };
}
