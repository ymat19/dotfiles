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
    pkgs.ollama
  ];

  # Whisper モデルを Nix store から配置
  whisper-model-base = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin";
    hash = "sha256-YO1bw90U7qhWST0zQ0m0BXgt3K8AKNS130CINF+6Lv4=";
  };

  voxtype-launcher = pkgs.writeShellScript "voxtype-launcher" ''
    export PATH="${voxtypePath}"
    mkdir -p "$HOME/.local/share/voxtype/models"
    ln -sf ${whisper-model-base} "$HOME/.local/share/voxtype/models/ggml-base.bin"
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

    [output.post_process]
    command = "ollama run gemma3:4b '以下の口述テキストを整形してください。句読点を修正し、必要に応じて改行を入れてください。整形したテキストのみを出力し、それ以外は何も出力しないでください:'"
    timeout_ms = 30000

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
