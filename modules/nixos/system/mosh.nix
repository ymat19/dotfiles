{ ... }:

{
  # mosh-server が UDP セッションに使うポート範囲を開放する。
  # mosh パッケージ自体は共通モジュール (modules/mosh.nix) で導入済み。
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 60000;
      to = 61000;
    }
  ];
}
