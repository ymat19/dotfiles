{ config, pkgs, lib, onNixOS, ... }:

(if onNixOS
then
  {
    home.packages = lib.mkAfter (with pkgs; [
      hyprland
      wofi
      kitty
    ]);

    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = builtins.readFile ../configs/hyprland.conf;
    };

    programs.hyprlock = {
      enable = true;
      extraConfig = builtins.readFile ../configs/hyprlock.conf;
    };
    ## ─ optional ─  一定時間アイドルになったら自動で Hyprlock を呼ぶ
    services.hypridle = {
      enable = true; # Hyprland 公式アイドaルデーモン :contentReference[oaicite:1]{index=1}
      settings = {
        general = { after = 300; }; # 300 秒アイドルで "lock" シグナル
        listener = [
          { on = "lock"; exec = "hyprlock"; } # 画面ロック
          { on = "after"; exec = "hyprctl dispatch dpms off"; } # さらに消灯
          { on = "resume"; exec = "hyprctl dispatch dpms on"; } # 復帰で点灯
        ];
      };
    };

    i18n.inputMethod = {
      enabled = "fcitx5";
      fcitx5.addons = with pkgs; [ fcitx5-mozc fcitx5-configtool ];
    };

    home.sessionVariables = lib.mkAfter ({
      XMODIFIERS = "@im=fcitx";
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      INPUT_METHOD = "fcitx";
    });
  }
else
  { })
