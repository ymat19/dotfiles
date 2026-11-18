{ inputs, ... }:

{
  # Codex デスクトップアプリ（非公式 Linux ビルド: ilysenko/codex-desktop-linux）
  # 公式の Linux 版アプリは無いが、OpenAI 公式の Linux 向け .deb を Nix でラップした flake がある。
  # home-manager のモジュールではなく NixOS のモジュールを使うのは、nix-ld を有効にしていると
  # サンドボックス内のコマンドが動くよう programs.nix-ld.libraries への追加が要り、
  # それを home-manager からは設定できないため。
  imports = [ inputs.codex-desktop-linux.nixosModules.default ];

  programs.codexDesktopLinux.enable = true;
}
