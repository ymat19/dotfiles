{ pkgs, lib, username, homeDirectory, onNixOS, ... }:

{
  # Thunar 本体（xfconfd の D-Bus サービス登録、プラグイン統合まで面倒を見てくれる）
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-volman # removable media management
    ];
  };

  # xfconf-query などの CLI も使えるようにしておく
  programs.xfconf.enable = true;

  environment.systemPackages = lib.mkAfter
    (with pkgs; [
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

  # Thunar のデフォルト表示設定
  # - 詳細リスト表示 (ThunarDetailsView)
  # - 最終更新日の降順 (新しい順)
  # Thunar は GUI 操作のたびにこのファイル（ウィンドウ列幅などのランタイム状態）を
  # 書き換えてシンボリックリンクを実体ファイルに置き換えてしまう。そのままだと
  # 次回 rebuild 時にバックアップ衝突で activation が失敗するため、force でリポジトリ
  # の初期値を毎回上書きする（GUI 由来の変更は破棄される割り切り）。
  home-manager.users.${username}.home.file.".config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml" = {
    source = ../../../configs/xfce4/xfconf/xfce-perchannel-xml/thunar.xml;
    force = true;
  };
}
