{ pkgs, lib, username, homeDirectory, onNixOS, ... }:

{
  services.xremap = {
    userName = username;
    serviceMode = "system";
    withHypr = true;
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
        # MetaLeft → F24
        {
          name = "MetaLeft to F24";
          remap = {
            "Super_L" = "F24";
          };
        }
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
  systemd.services.xremap = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}

