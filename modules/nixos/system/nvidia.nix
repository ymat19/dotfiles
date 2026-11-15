{
  boot.kernelModules = [ "nvidia" ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true; # Wayland を使うには必要
    powerManagement.enable = true; # 省電力オプション（任意）
    powerManagement.finegrained = false;
    open = false; # open はまだ不安定なので通常は false
    nvidiaSettings = true; # nvidia-settings GUI を使うなら
  };

  # ドライバ同梱プロファイルは Hyprland / kwin / mutter 等にしか GLVidHeapReuseRatio=0 を当てず、
  # niri は対象外。未設定だと niri が解放済み VRAM を抱え込み、モニタ再接続時の
  # スキャンアウトバッファ確保が "Failed to allocate NVKMS memory for GEM object" で失敗する
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules = [
        {
          pattern = {
            feature = "procname";
            matches = "niri";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
      ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 0;
            }
          ];
        }
      ];
    };

  # Wayland を有効にする（例: GDM + GNOME Wayland）
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.enable = true;

  # 必須: Wayland で NVIDIA を使うには modesetting と GBM バックエンドが必要
  environment.variables = {
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GL_GSYNC_ALLOWED = "0";
    __GL_VRR_ALLOWED = "0";
    WLR_NO_HARDWARE_CURSORS = "1"; # sway/hyprlandなどでハードウェアカーソル問題の回避
  };
}
