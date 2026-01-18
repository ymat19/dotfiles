{ pkgs, lib, username, homeDirectory, onNixOS, ... }:

{
  environment.systemPackages = lib.mkAfter
    (with pkgs; [
      thunar
      thunar-volman  # removable media management
      tumbler        # thumbnail generation
      gvfs                # virtual filesystem (SMB, FTP, etc.)
      samba               # SMB/CIFS support
      libsecret           # secret storage library for password persistence
    ]
    );

  # Enable gvfs service for network share support
  services.gvfs.enable = true;

  # Enable tumbler service for thumbnail generation
  services.tumbler.enable = true;
}
