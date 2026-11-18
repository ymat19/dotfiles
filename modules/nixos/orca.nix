{ pkgs, ... }:

{
  home.packages = [ (import ../../lib/orca.nix { inherit pkgs; }).package ];
}
