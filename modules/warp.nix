{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = lib.mkAfter (
    with pkgs;
    [
      warp-terminal
    ]
  );
}
