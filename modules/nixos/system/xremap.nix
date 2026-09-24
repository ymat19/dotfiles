{ pkgs, lib, username, homeDirectory, onNixOS, envName, ... }:

let
  niriSocketLink = "${homeDirectory}/.local/state/niri-ipc.sock";
in
{
  services.xremap = {
    enable = true;
    userName = username;
    serviceMode = "system";
    withNiri = true;
    # 既定では起動時に列挙したデバイスしか掴まず、スリープ復帰で USB が
    # 再列挙されると以降のリマップが黙って止まる。
    watch = true;
    config = {
      virtual_modifiers = [ "F24" ];
      modmap = [
        # CapsLock → Ctrl
        {
          name = "CapsLock to Ctrl";
          remap = {
            "CapsLock" = "Ctrl_L";
          };
        }
      ] ++ lib.optionals (envName == "air") [
        # MetaLeft → F24 (air only)
        {
          name = "MetaLeft to F24";
          remap = {
            "Super_L" = "F24";
          };
        }
      ] ++ [
        # Alt_L → F24
        {
          name = "Alt_L to F24";
          remap = {
            "Alt_L" = "F24";
          };
        }
      ];
      keymap = [
        # 既存の Ctrl‑h → Backspace
        {
          name = "Ctrl+H should be enabled on all apps as BackSpace";
          remap = {
            "C-h" = "Backspace";
          };
        }

        # Alt+HJKL → 矢印キー
        {
          name = "Alt+HJKL to Arrow keys";
          remap = {
            "F24-h" = "Left";
            "F24-j" = "Down";
            "F24-k" = "Up";
            "F24-l" = "Right";
          };
        }

        # Alt+1‑0, -, = → F1‑F12
        {
          name = "Alt+0~9,-,= to F1~F12";
          remap = {
            "F24-1" = "F1";
            "F24-2" = "F2";
            "F24-3" = "F3";
            "F24-4" = "F4";
            "F24-5" = "F5";
            "F24-6" = "F6";
            "F24-7" = "F7";
            "F24-8" = "F8";
            "F24-9" = "F9";
            "F24-0" = "F10";
            "F24-MINUS" = "F11"; # Alt+-
            "F24-EQUAL" = "F12"; # Alt+=
          };
        }
      ];
    };
  };
  systemd.services.xremap.serviceConfig = {
    Restart = lib.mkForce "on-failure";
    RestartSec = lib.mkForce "5s";
    Environment = [ "NIRI_SOCKET=${niriSocketLink}" ];
    # 上流 unit の ProtectHome=tmpfs はリンクもその先の /run/user も隠す。
    # 保護自体は外さず、niri ソケットに届く経路だけ見せる。
    # 先頭 "-" は未ログインや新規ホストで存在しなくても起動を失敗させないため。
    BindReadOnlyPaths = [
      "-/run/user"
      "-${dirOf niriSocketLink}"
    ];
  };

  # アプリ別 keymap（application.only）は niri の IPC で判定するが、xremap は
  # 接続先を NIRI_SOCKET 環境変数からしか取らず、system サービスには無い。
  # user サービス化はしない: 同じ uid の Wispr helper から隠すため root 専用に
  # した helper の仮想デバイス（wispr-flow.nix）を掴めなくなる。
  # ソケット名は niri の PID を含み毎回変わるので固定パスのリンクを張る。
  # xremap は判定可否をプロセス終了までキャッシュし、ログイン前に判定が走ると
  # 不可のまま固まるため、リンクを張った後に再起動して判定をやり直させる。
  systemd.user.services.xremap-niri-socket = {
    description = "Expose niri IPC socket to the xremap system service";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    unitConfig.ConditionUser = username;
    serviceConfig.Type = "oneshot";
    script = ''
      [ -n "''${NIRI_SOCKET:-}" ] || exit 0
      mkdir -p "$(dirname ${niriSocketLink})"
      ln -sfn "$NIRI_SOCKET" ${niriSocketLink}
      # configuration.nix の sudoers はフルパスで照合する
      exec /run/wrappers/bin/sudo -n /run/current-system/sw/bin/systemctl restart xremap
    '';
  };
}

