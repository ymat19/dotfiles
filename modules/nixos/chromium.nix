{
  pkgs,
  ...
}:

{
  # Chromium (aarch64 対応)。
  # Google Chrome は ARM64 Linux の実バイナリが未公開 (2026 Q2 リリース予定) かつ
  # nixpkgs も未対応のため、当面 Chromium を使う。Claude in Chrome 拡張も基本動作する。
  home.packages = [
    pkgs.chromium
  ];
}
