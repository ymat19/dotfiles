{ pkgs, lib, ... }:
let
  # wtype を除外した PATH
  # Niri の zwp_virtual_keyboard_v1 バグ (niri#2314) により
  # wtype 使用後にキーボード入力が不能になるため
  voxtypePath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.which
    pkgs.libnotify
    pkgs.dotool
    pkgs.ydotool
    pkgs.wl-clipboard
    pkgs.xclip
    pkgs.xdotool
  ];

  voxtype-launcher = pkgs.writeShellScript "voxtype-launcher" ''
    export PATH="${voxtypePath}"
    exec ${pkgs.voxtype}/bin/.voxtype-wrapped --no-hotkey daemon
  '';
in
{
  home.packages = [
    pkgs.voxtype
  ];

  xdg.configFile."voxtype/config.toml".text = ''
    state_file = "auto"

    [hotkey]
    enabled = false

    [audio]
    device = "default"
    sample_rate = 16000
    max_duration_secs = 60

    [whisper]
    model = "base"
    language = "ja"
    translate = false

    [output]
    mode = "paste"
    paste_keys = "ctrl+shift+v"
    fallback_to_clipboard = true
    restore_clipboard = true
    restore_clipboard_delay_ms = 300

    [output.notification]
    on_recording_start = true
    on_recording_stop = true
    on_transcription = true
  '';

  systemd.user.services.voxtype = {
    Unit = {
      Description = "Voxtype voice-to-text daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${voxtype-launcher}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
