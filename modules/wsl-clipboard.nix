{
  pkgs,
  lib,
  onWSL ? false,
  ...
}:

{
  # Claude Code 等の CLI が Windows 側でコピーした画像を貼り付けられるようにする。
  # xclip ではなく wl-clipboard を使うのは、WSLg の X11 側クリップボードには
  # テキストしか同期されず、画像 (image/bmp) は Wayland 側にしか出てこないため。
  home.packages = lib.mkIf onWSL [ pkgs.wl-clipboard ];
}
