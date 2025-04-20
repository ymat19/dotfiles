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
