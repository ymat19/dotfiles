{ config, pkgs, lib, ... }:

let
  cfg = config.programs._9router;
  _9router_pkg = pkgs.callPackage ../../pkgs/9router.nix { };
in
{
  options.programs._9router = {
    enable = lib.mkEnableOption "9router - AI coding router & token saver";

    port = lib.mkOption {
      type = lib.types.int;
      default = 20128;
      description = "Port for 9router dashboard and API proxy";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ _9router_pkg ];

    # Systemd user service for auto-start (headless mode)
    systemd.user.services."9router" = {
      Unit = {
        Description = "9Router - AI Coding Router & Token Saver";
        After = [ "network.target" ];
      };
      Service = {
        ExecStart = "${_9router_pkg}/bin/9router --port ${toString cfg.port} --no-browser --log";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "PORT=${toString cfg.port}"
        ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}