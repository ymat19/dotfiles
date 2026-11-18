# niri-vm.exe（Windows 用のランチャー）を Nix のある任意の Linux でクロスビルドする。
#   nix build .#winq-launcher   → result/bin/niri-vm.exe
#
# Try Omarchy for Windows（flake の入力 try-omarchy-windows、MIT License）のランチャー（app/）を
# 次の形で使う:
#   - upstreamFiles は上流のファイルをそのまま使う
#   - 上流の大きなファイル（丸ごと入れると上流のほぼ全体が要るもの）からは、excerpts.txt に名前を書いた
#     宣言だけを、ビルド時に tools/excerptgen で上流のまま抜き出す（excerpt_<上流のファイル名>）
#   - patches/ は、上の 2 つに当てる改変（理由は各パッチの先頭）
#   - supervise_windows.go・hook_windows.go は上流の関数を大きく削って書き直したもの（パッチに向かない規模）
#   - main.go・shim_windows.go・vdesk_windows.go・fullscreen_windows.go は自分で書いたもの
# 上流の LICENSE（MIT）はビルド時に上流から取り込む。
# 外部の Go モジュールに依存しないので vendorHash は null。
{
  lib,
  buildGoModule,
  tryOmarchy,
}:

let
  upstreamFiles = [
    "audio_endpoints_windows.go"
    "clipboard_bridge.go"
    "clipboard_cache.go"
    "clipboard_files.go"
    "clipboard_hdrop.go"
    "clipboard_image.go"
    "clipboard_item.go"
    "clipboard_state.go"
    "clipboard_transfer.go"
    "closeguard.go"
    "file_transfer.go"
    "file_transfer_service.go"
    "file_transfer_zip.go"
    "lifecycle.go"
    "ports.go"
    "qemu_bridge_windows.go"
    "qmp.go"
    "qmp_client.go"
    "qmp_control.go"
    "session_exit.go"
    "tcp_owner_windows.go"
    "transfer_progress.go"
    # 以下は patches/ で改変する
    "clipboard.go"
    "clipboard_files_windows.go"
    "qmp_control_windows.go"
  ];
in
buildGoModule {
  pname = "niri-vm";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      (lib.fileset.fileFilter (file: file.hasExt "go") ./.)
      ./go.mod
      ./patches
      ./excerpts.txt
    ];
  };

  postPatch = ''
    ${lib.concatMapStringsSep "\n" (f: "cp ${tryOmarchy}/app/${f} ${f}") upstreamFiles}
    chmod u+w ${lib.concatStringsSep " " upstreamFiles}
  '';

  vendorHash = null;

  # 抜き出しはビルド機向けに動かす（go のキャッシュが用意される configurePhase の後なので buildPhase で）。
  # パッチは抜き出しの後に当てる。buildGoModule は GOOS / GOARCH をビルド機に合わせているので、
  # その後で Windows 向けに上書きする。既定の go install だと bin/windows_amd64/ に入るので、名前を決めて自分でビルドする。
  # -H windowsgui: GUI サブシステム（起動してもコンソールの窓が出ない）。
  buildPhase = ''
    runHook preBuild
    go run ./tools/excerptgen ${tryOmarchy}/app excerpts.txt .
    for p in patches/*.patch; do patch -p1 --no-backup-if-mismatch < "$p"; done
    export GOOS=windows GOARCH=amd64 CGO_ENABLED=0
    go build -trimpath -ldflags "-H=windowsgui -s -w" -o niri-vm.exe .
    runHook postBuild
  '';

  # Windows の実行ファイルはビルド機では動かせない。
  doCheck = false;
  # Linux 用の strip / patchelf を PE ファイルにかけない（-s -w で既に小さくしている）。
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 niri-vm.exe $out/bin/niri-vm.exe
    install -Dm644 ${tryOmarchy}/LICENSE $out/share/licenses/niri-vm/LICENSE
    runHook postInstall
  '';

  meta = {
    description = "Launcher for the winq-emu NixOS VM on WINQ-EMU (Windows), based on Try Omarchy for Windows";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
