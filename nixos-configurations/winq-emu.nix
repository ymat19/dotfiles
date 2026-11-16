# winq-emu ホスト: WINQ-EMU（cmspam/winq-emu）上で niri を動かす VM 固有の設定。
# 起動は scripts/winq/start-niri-vm.ps1、イメージは
#   nix build .#nixosConfigurations.winq-emu.config.system.build.winqImage --impure
{
  config,
  lib,
  pkgs,
  modulesPath,
  username,
  ...
}:

{
  # BIOS ブート。WINQ-EMU は EFI（OVMF）だとタイマの都合で Venus(Vulkan) が
  # ~5fps まで落ちると明記しているため、baremetal.nix の systemd-boot を差し替える。
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  # シリアルにもカーネルログと getty を出す（launcher が serial.log に落とす）。
  # 最後の console= が /dev/console になるので tty0 を後ろに置く。
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty0"
  ];

  # WHPX の中ではネストした仮想化が使えないので libvirt 一式は外す
  programs.virt-manager.enable = lib.mkForce false;
  virtualisation.libvirtd.enable = lib.mkForce false;
  virtualisation.spiceUSBRedirection.enable = lib.mkForce false;
  # Bluetooth アダプタは VM に見えない
  hardware.bluetooth.enable = lib.mkForce false;

  # Windows からの ssh 用。launcher は 127.0.0.1 にだけ転送するので外には出ない。
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # 新規イメージの初回ログイン用。ログインしたら passwd で変えること。
  users.users.${username}.initialPassword = "changeme";

  # Windows の共有フォルダ（launcher の -Share、9p の mount_tag=hostshare）
  fileSystems."/mnt/windows" = {
    device = "hostshare";
    fsType = "9p";
    options = [
      "trans=virtio"
      "version=9p2000.L"
      "msize=1048576"
      "nofail"
      "noauto"
      "x-systemd.automount"
    ];
  };

  # 疎通確認用（glxinfo -B / vulkaninfo --summary で virgl・venus を確認する）
  environment.systemPackages = with pkgs; [
    mesa-demos
    vulkan-tools
  ];

  # WINQ-EMU 用ディスクイメージ。中身ぎりぎりの大きさで作り、Windows 側で
  #   C:\WINQ-EMU\bin\qemu-img.exe resize disk.qcow2 200G
  # のように広げる（起動時に growPartition と autoResize がパーティションと ext4 を追従させる）。
  # 最初から 200GiB で作ると、中身を書き込む cptofs（LKL）が途中で CPU 100% のまま
  # 書き込みが止まり、先に進まなかった。
  system.build.winqImage = import (modulesPath + "/../lib/make-disk-image.nix") {
    inherit config lib pkgs;
    name = "nixos-winq-emu";
    format = "qcow2";
    partitionTableType = "legacy";
    label = "nixos";
    diskSize = "auto";
    additionalSpace = "4G";
    installBootLoader = true;
    copyChannel = false;
  };
}
