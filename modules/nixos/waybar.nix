# Waybar configuration for Hyprland
{ inputs, pkgs, lib, hasBattery, ... }:
{
  # Explicitly disable HyprPanel to prevent conflicts
  programs.hyprpanel.enable = lib.mkForce false;
  
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 41;
        spacing = 4;
        
        # Left modules
        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
          "custom/updates"
          "disk"
        ] ++ (if hasBattery then ["battery"] else []);
        
        # Center modules  
        modules-center = [
          "mpris"
        ];
        
        # Right modules
        modules-right = [
          "cpu"
          "memory"
          "pulseaudio"
          "network"
          "bluetooth"
          "tray"
          "clock"
          "custom/notification"
        ];
        
        # Module configurations
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            "1" = "󰲠";
            "2" = "󰲢";
            "3" = "󰲤";
            "4" = "󰲦";
            "5" = "󰲨";
            "urgent" = "";
            "focused" = "";
            "default" = "";
          };
        };
        
        "hyprland/window" = {
          format = "{}";
          max-length = 50;
        };
        
        "custom/updates" = {
          format = "󰋼 {}";
          interval = 1440;
          exec = "jq '[.[].cvssv3_basescore | to_entries | add | select(.value > 7)] | length' <<< $(vulnix -S --json) 2>/dev/null || echo 0";
          tooltip = false;
        };
        
        "disk" = {
          interval = 30;
          format = "󰋊 {percentage_used}%";
          path = "/";
        };
        
        "battery" = lib.mkIf hasBattery {
          states = {
            good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰂄 {capacity}%";
          format-alt = "{icon} {time}";
          format-icons = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
        };
        
        "mpris" = {
          format = "󰎆 {title}";
          format-paused = "󰏤 {title}";
          max-length = 60;
          on-click = "playerctl play-pause";
        };
        
        "cpu" = {
          format = "󰻠 {usage}%";
          tooltip = false;
        };
        
        "memory" = {
          format = "󰍛 {}%";
        };
        
        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-bluetooth = "{icon}󰂯 {volume}%";
          format-bluetooth-muted = "󰂲 {icon}";
          format-muted = "󰖁";
          format-source = "󰍬 {volume}%";
          format-source-muted = "󰍭";
          format-icons = {
            headphone = "󰋋";
            hands-free = "󱡒";
            headset = "󰋎";
            phone = "󰄜";
            portable = "󰦧";
            car = "󰄋";
            default = ["󰕿" "󰖀" "󰕾"];
          };
          on-click = "pavucontrol";
          on-click-right = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
        };
        
        "network" = {
          format-wifi = "󰤨 {signalStrength}%";
          format-ethernet = "󰈀 {ipaddr}/{cidr}";
          tooltip-format = "󰈀 {ifname} via {gwaddr}";
          format-linked = "󰈀 {ifname} (No IP)";
          format-disconnected = "󰤭 Disconnected";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
        };
        
        "bluetooth" = {
          format = "󰂯 {status}";
          format-connected = "󰂱 {device_alias}";
          format-connected-battery = "󰂱 {device_alias} {device_battery_percentage}%";
          tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
          tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
          tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
        };
        
        "tray" = {
          spacing = 10;
        };
        
        "clock" = {
          format = "{:%Y/%m/%d  %H:%M:%S}";
          format-alt = "󰃭 {:%A, %B %d, %Y}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          interval = 1;
        };
        
        "custom/notification" = {
          tooltip = false;
          format = "{icon}";
          format-icons = {
            notification = "󰂚<span foreground='red'><sup></sup></span>";
            none = "󰂚";
            dnd-notification = "󰂛<span foreground='red'><sup></sup></span>";
            dnd-none = "󰂛";
            inhibited-notification = "󰂚<span foreground='red'><sup></sup></span>";
            inhibited-none = "󰂚";
            dnd-inhibited-notification = "󰂛<span foreground='red'><sup></sup></span>";
            dnd-inhibited-none = "󰂛";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
        };
      };
    };
    
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 14px;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(43, 48, 59, 0.5);
        border-bottom: 3px solid rgba(100, 114, 125, 0.5);
        color: #ffffff;
        transition-property: background-color;
        transition-duration: .5s;
      }

      button {
        box-shadow: inset 0 -3px transparent;
        border: none;
        border-radius: 0;
      }

      button:hover {
        background: inherit;
        box-shadow: inset 0 -3px #ffffff;
      }

      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: #ffffff;
      }

      #workspaces button:hover {
        background: rgba(0, 0, 0, 0.2);
      }

      #workspaces button.active {
        background-color: #64727D;
        box-shadow: inset 0 -3px #ffffff;
      }

      #workspaces button.urgent {
        background-color: #eb4d4b;
      }

      #mode {
        background-color: #64727D;
        border-bottom: 3px solid #ffffff;
      }

      #clock,
      #battery,
      #cpu,
      #memory,
      #disk,
      #temperature,
      #backlight,
      #network,
      #pulseaudio,
      #bluetooth,
      #wireplumber,
      #custom-media,
      #tray,
      #mode,
      #idle_inhibitor,
      #scratchpad,
      #mpris,
      #custom-updates,
      #custom-notification,
      #window {
        padding: 0 10px;
        margin: 3px 0;
        color: #ffffff;
      }

      #window {
        border-radius: 10px;
        font-weight: bold;
      }

      #workspaces {
        margin: 0 4px;
      }

      .modules-left > widget:first-child > #workspaces {
        margin-left: 0;
      }

      .modules-right > widget:last-child > #workspaces {
        margin-right: 0;
      }

      #clock {
        background-color: #64727D;
        border-radius: 10px;
      }

      #battery {
        background-color: #ffffff;
        color: #000000;
        border-radius: 10px;
      }

      #battery.charging, #battery.plugged {
        color: #ffffff;
        background-color: #26A65B;
      }

      @keyframes blink {
        to {
          background-color: #ffffff;
          color: #000000;
        }
      }

      #battery.critical:not(.charging) {
        background-color: #f53c3c;
        color: #ffffff;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      #cpu {
        background-color: #2ecc71;
        color: #ffffff;
        border-radius: 10px;
      }

      #memory {
        background-color: #9b59b6;
        border-radius: 10px;
      }

      #disk {
        background-color: #964B00;
        border-radius: 10px;
      }

      #network {
        background-color: #2980b9;
        border-radius: 10px;
      }

      #network.disconnected {
        background-color: #f53c3c;
      }

      #pulseaudio {
        background-color: #f1c40f;
        color: #ffffff;
        border-radius: 10px;
      }

      #pulseaudio.muted {
        background-color: #90b1b1;
        color: #2a5c45;
      }

      #bluetooth {
        background-color: #1abc9c;
        border-radius: 10px;
      }

      #bluetooth.disconnected {
        background-color: #f53c3c;
      }

      #mpris {
        background-color: #66cc99;
        color: #ffffff;
        min-width: 100px;
        border-radius: 10px;
      }

      #tray {
        background-color: #2980b9;
        border-radius: 10px;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #eb4d4b;
      }

      #custom-updates {
        background-color: #e74c3c;
        color: #ffffff;
        border-radius: 10px;
      }

      #custom-notification {
        background-color: #3498db;
        border-radius: 10px;
      }
    '';
  };

  # Add necessary packages for waybar modules
  home.packages = lib.mkAfter (with pkgs; [
    power-profiles-daemon
    jq
    vulnix
    pavucontrol
    pulseaudio
    brightnessctl
    gcolor3
    # For notifications
    swaynotificationcenter
    # For media control
    playerctl
    # Nerd fonts
    nerd-fonts.jetbrains-mono
  ]);
}