{ pkgs, ... }:
{
  programs.steam = {

    enable = true;

    remotePlay.openFirewall = true;

    dedicatedServer.openFirewall = true;

    # === 再発防止(宣言的) ===
    # 症状: niri(Wayland)+ NVIDIA + XWayland(xwayland-satellite)環境で、Proton ゲームが
    #   フレームを描き続けていても niri に latch されず古いバッファで固着する
    #   presentation スタック(ゲーム/GPU は正常なのに画面だけ止まる)。
    #
    # 方針: Steam のゲーム別「起動オプション」は Steam が localconfig.vdf で実行時管理して
    #   おり nixpkgs から宣言的に設定できない(= gamescope を起動オプションで噛ませる手法は
    #   非宣言的)。代わりに steam モジュールの `apply`(steam.override { extraEnv = … })を
    #   使い、全ゲームへ環境変数を一括注入する。
    #
    # 対策: PROTON_ENABLE_WAYLAND=1 で Proton ゲームを XWayland 経由ではなく native Wayland
    #   クライアントとして走らせ、xwayland-satellite → niri の固着経路そのものを消す。
    #   Proton 10(Hotfix 含む)は Wayland ドライバを内蔵しているため認識される。
    #   ※ もし特定ゲームが native Wayland で不調なら、この行を消せば元(XWayland)に戻る。
    package = pkgs.steam.override {
      extraEnv = {
        PROTON_ENABLE_WAYLAND = "1";
        # SteamVR の vrmonitor は同梱 Qt に xcb プラグインしか持たないため、niri セッションが
        # 渡す QT_QPA_PLATFORM=wayland;xcb では起動時に即クラッシュする。Wayland デスクトップ
        # でも xcb に固定して XWayland(:0) 経由で動かす。Steam 本体 UI は CEF なので影響なし。
        QT_QPA_PLATFORM = "xcb";
      };
    };

  };

  # フォールバック用に gamescope も入れておく(native Wayland で不調なゲームがあれば
  # 個別に `gamescope -f -W 3440 -H 1440 -- %command%` で包める)。宣言的一括対策は
  # 上の PROTON_ENABLE_WAYLAND 側。
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
}
