{ pkgs, lib, ... }:

{
  # dms の settings.json はランタイムで dms 自身が書き換えるため symlink 管理できない。
  # 全環境で固定したい値を jq で in-place 上書きする。
  # - matugenTemplateNeovim: 出力先 (~/.config/nvim/lua/plugins/) が home-manager 管理下で
  #   read-only のため壁紙変更時に失敗する。生成物も使っていないので無効化。
  # - popup/dockTransparency: 全環境で同じ見た目に揃える。
  home.activation.applyDmsSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SETTINGS="$HOME/.config/DankMaterialShell/settings.json"
    if [ -f "$SETTINGS" ]; then
      ${pkgs.jq}/bin/jq '
        .matugenTemplateNeovim = false |
        .popupTransparency = 0.8 |
        .dockTransparency = 0.8
      ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    fi
  '';
}
