{ config, pkgs, lib, ... }:

let
  cfg = config.programs._9router;
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
    home.packages = with pkgs; [
      nodejs_22
    ];

    xdg.configFile."9router/config.json" = {
      source = ../../configs/9router/config.json;
    };

    home.sessionPath = [
      "$HOME/.npm-global/bin"
    ];

    home.sessionVariables = {
      NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    };
  };
}