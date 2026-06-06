{
  pkgs,
  inputs,
  ...
}:

{
  # Claude Desktop (非公式 Linux ビルド: aaddrick/claude-desktop-debian)
  # 公式は macOS/Windows のみ。Linux は CLI が公式パスだが、GUI も使いたいので導入。
  # MCP サーバーを使うため FHS 環境版 (claude-desktop-fhs) を選択。
  home.packages = [
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-fhs
  ];
}
