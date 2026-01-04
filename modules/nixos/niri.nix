{ config, pkgs, lib, envName, ... }:

{
  home.packages = with pkgs; [
    niri
    waypaper    # 壁紙管理GUI
    mpvpaper    # 動画壁紙
  ];

  # Niri KDL設定ファイル（envName別に動的生成）
  xdg.configFile."niri/config.kdl" = let
    baseConfig = builtins.readFile ../../configs/niri-base.kdl;

    # Air専用キーバインドを既存のbindsブロック内に追加
    airKeybinds = lib.optionalString (envName == "air") ''
    // Air (Apple Silicon) specific keybinds
    Mod+Z { spawn "niri" "msg" "output" "eDP-1" "scale" "1.0666667"; }
    Mod+Shift+Z { spawn "niri" "msg" "output" "eDP-1" "scale" "1.0"; }
    Mod+I { spawn "niri" "msg" "input" "device" "apple-mtp-multi-touch" "enabled" "true"; }
    Mod+Shift+I { spawn "niri" "msg" "input" "device" "apple-mtp-multi-touch" "enabled" "false"; }
'';

    # bindsブロックの終わり（}の前）にair専用キーバインドを挿入
    configWithAirBinds = if envName == "air" then
      builtins.replaceStrings
        ["    // Quit\n    Mod+Shift+C { quit; }\n}"]
        ["    // Quit\n    Mod+Shift+C { quit; }\n\n${airKeybinds}}\n"]
        baseConfig
    else baseConfig;

    # Dyna専用の出力設定を追加
    dynaOutput = lib.optionalString (envName == "dyna") ''

// Dyna specific: disable internal display
output "eDP-1" {
    off
}
'';
  in {
    text = configWithAirBinds + dynaOutput;
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

  # Niri用環境変数
  home.sessionVariables = lib.mkAfter (
    {
      XMODIFIERS = "@im=fcitx";
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      INPUT_METHOD = "fcitx";
      XDG_SESSION_TYPE = "wayland";
      GTK_THEME = "Adwaita-dark";
      QT_STYLE_OVERRIDE = "adwaita-dark";
    } // lib.optionalAttrs (envName == "main") {
      # NVIDIA専用設定
      WLR_NO_HARDWARE_CURSORS = "1";
      LIBVA_DRIVER_NAME = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
    }
  );
}
