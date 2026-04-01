{ pkgs, lib, ... }:
let
  # wtype を除外した PATH
  # Niri の zwp_virtual_keyboard_v1 バグ (niri#2314) により
  # wtype 使用後にキーボード入力が不能になるため
  voxtypePath = lib.makeBinPath [
    pkgs.bash
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
  whisper-model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin";
    hash = "sha256-G+OpsgY4Z7k35k4ux0gzZKeZF+FX+pjF2UtcH//qmHs=";
  };

  voxtype-launcher = pkgs.writeShellScript "voxtype-launcher" ''
    export PATH="$HOME/.local/bin:${voxtypePath}"
    mkdir -p "$HOME/.local/share/voxtype/models"
    ln -sf ${whisper-model} "$HOME/.local/share/voxtype/models/ggml-small.bin"
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
    model = "small"
    language = "ja"
    translate = false

    [output]
    mode = "paste"
    paste_keys = "ctrl+shift+v"
    fallback_to_clipboard = true
    restore_clipboard = true
    restore_clipboard_delay_ms = 300

    [output.post_process]
    command = "claude -p '音声認識の出力を補正・整形してください。誤認識と思われる単語は文脈から正しい日本語に修正してください。句読点を適切に付け、意味の区切りで改行してください。補正後のテキストのみを出力してください。' --model opus --tools \"\" --strict-mcp-config"
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
