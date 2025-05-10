{ pkgs, lib, username, homeDirectory, onNixOS, ... }:

{
  environment.systemPackages = lib.mkAfter
    (with pkgs; [
      kdePackages.dolphin
      kdePackages.qtsvg
      kdePackages.kio-fuse #to mount remote filesystems via FUSE
      kdePackages.kio-extras #extra protocols support (sftp, fish and more)
    ]
    );
}
