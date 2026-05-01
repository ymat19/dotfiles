{
  config,
  pkgs,
  lib,
  envName,
  inputs,
  ...
}:

{
  home.packages = with pkgs; [
    waypaper
    adwaita-qt
    adwaita-qt6
    hypridle
    grim
    slurp
    satty
    inputs.niri-scratchpad.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # VLC: niri で映像が見切れる問題のワークアラウンド
  # https://github.com/niri-wm/niri/issues/2892
  # xwayland-satellite (DISPLAY=:0) 経由で起動させる
  xdg.desktopEntries.vlc = {
    name = "VLC media player";
    genericName = "Media player";
    comment = "Read, capture, broadcast your multimedia streams";
    icon = "vlc";
    exec = "env DISPLAY=:0 vlc --started-from-file %U";
    terminal = false;
    type = "Application";
    categories = [
      "AudioVideo"
      "Player"
      "Recorder"
    ];
    mimeType = [
      "application/ogg"
      "application/x-ogg"
      "audio/ogg"
      "audio/vorbis"
      "audio/x-vorbis"
      "audio/x-vorbis+ogg"
      "video/ogg"
      "video/x-ogm"
      "video/x-ogm+ogg"
      "video/x-theora+ogg"
      "video/x-theora"
      "audio/x-speex"
      "audio/opus"
      "application/x-flac"
      "audio/flac"
      "audio/x-flac"
      "audio/x-ms-asf"
      "audio/x-ms-asx"
      "audio/x-ms-wax"
      "audio/x-ms-wma"
      "video/x-ms-asf"
      "video/x-ms-asf-plugin"
      "video/x-ms-asx"
      "video/x-ms-wm"
      "video/x-ms-wmv"
      "video/x-ms-wmx"
      "video/x-ms-wvx"
      "video/x-msvideo"
      "audio/x-pn-windows-acm"
      "video/divx"
      "video/msvideo"
      "video/vnd.divx"
      "video/avi"
      "video/x-avi"
      "application/vnd.rn-realmedia"
      "application/vnd.rn-realmedia-vbr"
      "audio/vnd.rn-realaudio"
      "audio/x-pn-realaudio"
      "audio/x-pn-realaudio-plugin"
      "audio/x-real-audio"
      "audio/x-realaudio"
      "video/vnd.rn-realvideo"
      "audio/mpeg"
      "audio/mpg"
      "audio/mp1"
      "audio/mp2"
      "audio/mp3"
      "audio/x-mp1"
      "audio/x-mp2"
      "audio/x-mp3"
      "audio/x-mpeg"
      "audio/x-mpg"
      "video/mp2t"
      "video/mpeg"
      "video/mpeg-system"
      "video/x-mpeg"
      "video/x-mpeg2"
      "video/x-mpeg-system"
      "application/mpeg4-iod"
      "application/mpeg4-muxcodetable"
      "application/x-extension-m4a"
      "application/x-extension-mp4"
      "audio/aac"
      "audio/m4a"
      "audio/mp4"
      "audio/x-m4a"
      "audio/x-aac"
      "video/mp4"
      "video/mp4v-es"
      "video/x-m4v"
      "application/x-quicktime-media-link"
      "application/x-quicktimeplayer"
      "video/quicktime"
      "application/x-matroska"
      "audio/x-matroska"
      "video/x-matroska"
      "video/webm"
      "audio/webm"
      "audio/3gpp"
      "audio/3gpp2"
      "audio/AMR"
      "audio/AMR-WB"
      "video/3gp"
      "video/3gpp"
      "video/3gpp2"
      "x-scheme-handler/mms"
      "x-scheme-handler/mmsh"
      "x-scheme-handler/rtsp"
      "x-scheme-handler/rtp"
      "x-scheme-handler/rtmp"
      "x-scheme-handler/icy"
      "x-scheme-handler/icyx"
      "application/x-cd-image"
      "x-content/video-vcd"
      "x-content/video-svcd"
      "x-content/video-dvd"
      "x-content/audio-cdda"
      "x-content/audio-player"
      "application/ram"
      "application/xspf+xml"
      "audio/mpegurl"
      "audio/x-mpegurl"
      "audio/scpls"
      "audio/x-scpls"
      "text/google-video-pointer"
      "text/x-google-video-pointer"
      "video/vnd.mpegurl"
      "application/vnd.apple.mpegurl"
      "application/vnd.ms-asf"
      "application/vnd.ms-wpl"
      "application/sdp"
      "audio/dv"
      "video/dv"
      "audio/x-aiff"
      "audio/x-pn-aiff"
      "video/x-anim"
      "video/x-nsv"
      "video/fli"
      "video/flv"
      "video/x-flc"
      "video/x-fli"
      "video/x-flv"
      "audio/wav"
      "audio/x-pn-au"
      "audio/x-pn-wav"
      "audio/x-wav"
      "audio/x-adpcm"
      "audio/ac3"
      "audio/eac3"
      "audio/vnd.dts"
      "audio/vnd.dts.hd"
      "audio/vnd.dolby.heaac.1"
      "audio/vnd.dolby.heaac.2"
      "audio/vnd.dolby.mlp"
      "audio/basic"
      "audio/midi"
      "audio/x-ape"
      "audio/x-gsm"
      "audio/x-musepack"
      "audio/x-tta"
      "audio/x-wavpack"
      "audio/x-shorten"
      "application/x-shockwave-flash"
      "application/x-flash-video"
      "misc/ultravox"
      "image/vnd.rn-realpix"
      "audio/x-it"
      "audio/x-mod"
      "audio/x-s3m"
      "audio/x-xm"
      "application/mxf"
    ];
    settings = {
      Keywords = "Player;Capture;DVD;Audio;Video;Server;Broadcast;";
    };
  };

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
  xdg.configFile."niri/config.kdl" =
    let
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
      envKeybinds =
        if envName == "air" then
          airKeybinds
        else if envName == "dyna" then
          dynaKeybinds
        else
          "";

      configWithEnvBinds =
        if envKeybinds != "" then
          builtins.replaceStrings
            [ "    // Quit\n    Mod+Shift+C { quit; }\n\n    // Media keys" ]
            [ "    // Quit\n    Mod+Shift+C { quit; }\n\n${envKeybinds}    // Media keys" ]
            baseConfig
        else
          baseConfig;

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
    in
    {
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
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      qt6Packages.fcitx5-configtool
    ];
  };

  home.sessionVariables = lib.mkAfter ({
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
