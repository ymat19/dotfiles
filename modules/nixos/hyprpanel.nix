# https://zenn.dev/watagame/articles/hyprland-nix#statusbar
{ inputs, pkgs, lib, hasBattery, ... }:
{
  imports = [ inputs.hyprpanel.homeManagerModules.hyprpanel ];

  home.packages = lib.mkAfter (with pkgs; [
    power-profiles-daemon
    jq
    vulnix
    pavucontrol
    pulseaudio
    brightnessctl
    #btop
    gcolor3
  ]);

  programs.hyprpanel = {

    # Enable the module.
    # Default: false
    enable = true;

    # Automatically restart HyprPanel with systemd.
    # Useful when updating your config so that you
    # don't need to manually restart it.
    # Default: false
    systemd.enable = true;

    # Add '/nix/store/.../hyprpanel' to your
    # Hyprland config 'exec-once'.
    # Default: false
    hyprland.enable = true;

    # Fix the overwrite issue with HyprPanel.
    # See below for more information.
    # Default: false
    overwrite.enable = true;

    # Import a theme from './themes/*.json'.
    # Default: ""
    #theme = "gruvbox_split";

    # Override the final config with an arbitrary set.
    # Useful for overriding colors in your selected theme.
    # Default: {}
    override = {
      theme.bar.menus.text = "#123ABC";
    };

    # Configure bar layouts for monitors.
    # See 'https://hyprpanel.com/configuration/panel.html'.
    # Default: null
    #layout = {
    #  "bar.layouts" = {
    #    "0" = {
    #      left = [ "dashboard" "workspaces" ];
    #      middle = [ "media" ];
    #      right = [ "volume" "systray" "notifications" ];
    #    };
    #  };
    #};

    # Configure and theme almost all options from the GUI.
    # Options that require '{}' or '[]' are not yet implemented,
    # except for the layout above.
    # See 'https://hyprpanel.com/configuration/settings.html'.
    # Default: <same as gui>
    settings = {
      bar.launcher.autoDetectIcon = true;
      bar.workspaces.show_icons = true;
      bar.clock.format = "%Y/%m/%d  %H:%M:%S";

      menus.clock = {
        time = {
          military = true;
        };
        weather.unit = "metric";
      };

      menus.dashboard.directories.enabled = false;
      menus.dashboard.stats.enable_gpu = true;

      theme.bar.transparent = true;

      theme.font = {
        name = "CaskaydiaCove NF";
        size = "14px";
      };

      layout = {
        "bar.layouts" =
          let
            layout =
              {
                "left" = [
                  "dashboard"
                  "workspaces"
                  "windowtitle"
                  "updates"
                  "storage"
                ] ++ (if hasBattery then [ "battery" ] else [ ]);
                "middle" = [
                  "media"
                ];
                "right" = [
                  "cpu"
                  "ram"
                  "volume"
                  "network"
                  "bluetooth"
                  "systray"
                  "clock"
                  "notifications"
                ];
              };
          in
          {
            "0" = layout;
            "1" = layout;
            "2" = layout;
            "3" = layout;
          };
      };
      bar.customModules.updates.pollingInterval = 1440000;
      theme.name = "catppuccin_mocha";
      theme.bar.floating = false;
      theme.bar.buttons.enableBorders = true;
      menus.clock.time.hideSeconds = false;
      bar.media.show_active_only = true;
      bar.notifications.show_total = false;
      theme.bar.buttons.modules.ram.enableBorder = false;
      bar.battery.hideLabelWhenFull = true;
      menus.dashboard.controls.enabled = false;
      menus.dashboard.shortcuts.enabled = true;
      menus.clock.weather.enabled = false;
      menus.dashboard.shortcuts.right.shortcut1.command = "${pkgs.gcolor3}/bin/gcolor3";
      menus.media.displayTime = true;
      menus.power.lowBatteryNotification = true;
      bar.customModules.updates.updateCommand = "jq '[.[].cvssv3_basescore | to_entries | add | select(.value > 5)] | length' <<< $(vulnix -S --json)";
      bar.customModules.updates.icon.updated = "󰋼";
      bar.customModules.updates.icon.pending = "󰋼";
      bar.volume.rightClick = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
      bar.volume.middleClick = "pavucontrol";
      bar.media.format = "{title}";
    };
  };
}
