# winq-emu ホスト: WINQ-EMU（omacom/try-omarchy-windows が単体配布しているランタイム）上で
# niri を動かす VM 固有の設定。
# 起動は Windows のランチャー niri-vm.exe（scripts/winq/launcher、nix build .#winq-launcher）、イメージは
#   WINQ_INITIAL_PASSWORD_HASH=$(mkpasswd) nix build .#nixosConfigurations.winq-emu.config.system.build.winqImage --impure
{
  config,
  lib,
  pkgs,
  modulesPath,
  username,
  inputs,
  ...
}:

let
  # ランチャーとつなぐゲスト側のスクリプト（Try Omarchy for Windows のもの。scripts/winq/guest を参照）
  winqGuest = pkgs.callPackage ../scripts/winq/guest { tryOmarchy = inputs.try-omarchy-windows; };
  # 初回ログイン用のパスワードのハッシュ（mkpasswd の出力）。リポジトリには書かず、イメージのビルド時に渡す。
  initialPasswordHash = builtins.getEnv "WINQ_INITIAL_PASSWORD_HASH";
in
{
  # クリップボード連携のゲスト側。ランチャーが 127.0.0.1 で待ち、ゲストからは QEMU の
  # user ネットワーク越しに 10.0.2.2 で届く。Try Omarchy の clipboard-bridge.service と同じ
  # グラフィカルセッションへのつなぎ方（ExecStart だけ Nix のパッケージに向けた）。
  systemd.user.services.clipboard-bridge = {
    description = "Clipboard bridge to the Windows host (Try Omarchy)";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${winqGuest}/bin/clipboard-bridge";
      Restart = "always";
      RestartSec = 3;
    };
  };

  # ランチャーは QEMU を -no-reboot で動かし、ゲストの再起動で QEMU が終わったら起動し直す。
  # 再起動か電源オフかは QMP の SHUTDOWN イベントで決めるが、それが届かずに QEMU が
  # 終わったときのために、シャットダウンの途中（ネットワークが落ちる前）でランチャーに知らせる。
  # Try Omarchy の try-omarchy-reboot-notify.service と同じ定義。
  systemd.services.winq-reboot-notify = {
    description = "Tell the Windows launcher when a reboot (not poweroff) starts";
    after = [
      "network.target"
      "NetworkManager.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "${winqGuest}/bin/reboot-notify";
      TimeoutStopSec = 5;
    };
  };

  # ランチャーは対応するランタイムなら virtio-balloon の free page reporting を有効にする
  # （ゲストが空けたページを Windows に返す）。必要な virtio_balloon は qemu-guest.nix が
  # initrd に入れ、CONFIG_PAGE_REPORTING はカーネルの既定で有効なので、ゲスト側の設定は要らない。

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

  # journal もシリアルへ流し、QEMU が落ちる直前のログを Windows 側の serial.log に残す。
  # ゲストのディスク上の journal は、QEMU が落ちると直前の 20〜30 秒分が書き出されずに失われるため。
  # 量は平均 30 バイト/秒ほどで、負荷は無視できる。
  services.journald.settings.Journal = {
    ForwardToConsole = true;
    TTYPath = "/dev/ttyS0";
    MaxLevelConsole = "info";
  };

  # Windows の VM はホストの Hyper-V で動かし、入れ子の仮想化はしない方針なので libvirt 一式は外す
  programs.virt-manager.enable = lib.mkForce false;
  virtualisation.libvirtd.enable = lib.mkForce false;
  virtualisation.spiceUSBRedirection.enable = lib.mkForce false;
  # Bluetooth アダプタは VM に見えない
  hardware.bluetooth.enable = lib.mkForce false;

  # GNOME Keyring は使わない（niri のモジュールが既定で有効にする）。画面にログインするまで開かないため、
  # 再起動後にログインしないまま動くもの（gh など）が保存した資格情報を読めない。
  services.gnome.gnome-keyring.enable = false;
  security.pam.services.greetd.enableGnomeKeyring = lib.mkForce false; # baremetal.nix が有効にしている

  # 起動したらそのまま niri にログインする（dms-greeter のモジュールの自動ログイン。起動直後の 1 回だけで、
  # ログアウトすると通常のログイン画面になる）。VM は Windows のサインインの内側でしか開けない。
  services.displayManager.autoLogin = {
    enable = true;
    user = username;
  };

  # ホストの Windows の Hyper-V を操作する Skill と、その接続先（docs/winq-emu.md の「VM から Hyper-V を操作する」）。
  # winq-emu にだけ入れる。
  home-manager.users.${username} = {
    programs.agent-skills.skills.enable = [ "windows-hyperv" ];
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."windows-host" = {
        HostName = "10.0.2.2";
        User = "hyperv-ssh";
        IdentityFile = "~/.ssh/windows_ed25519";
        IdentitiesOnly = true;
      };
    };
  };

  # Windows からの ssh 用。launcher は 127.0.0.1 にだけ転送するので外には出ない。鍵でだけ入れる。
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # 新規イメージの初回ログイン用。作成済みのユーザーには効かない（mutableUsers）。
  users.users.${username}.initialHashedPassword = lib.mkIf (initialPasswordHash != "") initialPasswordHash;

  # Windows の共有フォルダ（launcher の -share、9p の mount_tag=hostshare）
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
  #   %LOCALAPPDATA%\WINQ-EMU\bin\qemu-img.exe resize disk.qcow2 200G
  # のように広げる（起動時に growPartition と autoResize がパーティションと ext4 を追従させる）。
  # 最初から 200GiB で作ると、中身を書き込む cptofs（LKL）が途中で CPU 100% のまま
  # 書き込みが止まり、先に進まなかった。
  system.build.winqImage =
    assert lib.assertMsg (initialPasswordHash != "")
      "WINQ_INITIAL_PASSWORD_HASH に初回ログイン用のパスワードのハッシュ（mkpasswd の出力）を入れて --impure でビルドする";
    import (modulesPath + "/../lib/make-disk-image.nix") {
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
