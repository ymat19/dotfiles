# WINQ-EMU（Windows 上の QEMU + WHPX）で動かす VM 用。
# nixos-generate-config の生成物ではなく、nixos-configurations/winq-emu.nix の
# ディスクイメージ（MBR 1 パーティション、ラベル nixos）に合わせて手で書いている。
{
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "ahci"
    "sr_mod"
  ];
  # greeter が出る前から virtio-gpu の KMS を掴ませ、simpledrm との取り合いを避ける
  boot.initrd.kernelModules = [ "virtio_gpu" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };
  # Windows 側で qemu-img resize したときにパーティションも追従させる
  boot.growPartition = true;

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
