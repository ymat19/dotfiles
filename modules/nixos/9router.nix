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

    xdg.configFile."9router/config.json" = {
      source = ../../configs/9router/config.json;
    };
  };
}