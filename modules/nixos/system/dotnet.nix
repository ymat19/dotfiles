{ pkgs, lib, username, homeDirectory, onNixOS, ... }:

{
  environment.systemPackages = lib.mkAfter
    (with pkgs; [
      dotnetCorePackages.sdk_8_0_1xx-bin
    ]
    );
}
