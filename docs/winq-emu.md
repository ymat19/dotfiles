# winq-emu: Windows 上で niri を動かす VM

Windows 上の [WINQ-EMU](https://github.com/cmspam/winq-emu)（WHPX と GPU 転送に対応した QEMU のビルド）で、
このリポジトリの NixOS（niri + DMS）を VM として動かす。ホスト名は `winq-emu`。

- CPU は WHPX（Windows Hypervisor Platform）で `-cpu host` のまま動く
- 描画は virtio-gpu 経由で Windows の GPU に転送する（OpenGL は virgl、Vulkan は Venus）。単体 GPU が無くても CPU 内蔵 GPU で動く
- Hyper-V の VM と違って画面が CPU 描画にならないので、niri のアニメーションも実用的な速さで動く

## 構成

| ファイル | 役割 |
|---|---|
| `flake.nix` の `winq-emu` | ホスト定義。WSL 上でビルドしても `onWSL = false` に固定し、`/etc/nixos` の無い環境でも出力する |
| `hardware-configuration/winq-emu/` | QEMU ゲスト用のハードウェア設定（virtio、ラベル `nixos` のルート、起動時に自動拡張） |
| `nixos-configurations/winq-emu.nix` | VM 固有の設定と qcow2 イメージの出力（`system.build.winqImage`） |
| `modules/nixos/system/xremap.nix` | `winq-emu` のときだけ Menu キー（`KEY_COMPOSE`）を Super に戻す |
| `scripts/winq/start-niri-vm.ps1` | Windows 側の起動スクリプト |
| `scripts/winq/rwin-to-menu.reg` | 右 Win を Menu キーに変換するレジストリ（Scancode Map） |

## 必要なもの

- Windows 10/11（x64）。仮想化支援が有効で、ハイパーバイザが動いていること
  （メモリ整合性 / VBS が有効なら追加設定は不要。そうでなければ「Windows ハイパーバイザー プラットフォーム」を有効化して再起動）
- GPU ドライバは新しいものに更新しておく（Venus は Windows 側の Vulkan ドライバを使う）
- イメージをビルドする Linux。ここでは WSL2 の Ubuntu を使う（KVM が使えること）
- メモリは 32GB 以上を推奨（VM に 24GB を割り当てる既定値の場合）

## 1. WINQ-EMU を入れる

[リリース](https://github.com/cmspam/winq-emu/releases)の `WINQ-EMU-Alpha10-Setup.exe` を実行する（管理者権限が必要、署名なし）。
既定の `C:\WINQ-EMU` に入る前提で書いている。

## 2. WSL でイメージをビルドする

### WSL のメモリ上限

既定（物理メモリの半分）だと、イメージ作成中にページキャッシュで上限に張り付き、WSL 全体が応答しなくなることがある。
`%USERPROFILE%\.wslconfig` で上限を上げてから `wsl --shutdown` する。

```ini
[wsl2]
memory=48GB
```

### Nix

`kvm` 機能はイメージ作成（内部で VM を使う）に、`trusted-users` はこの flake のキャッシュ（`nixConfig`）を使うのに要る。

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm \
  --extra-conf "trusted-users = root $(whoami)" \
  --extra-conf "extra-system-features = kvm"
```

Nix のビルド用ユーザーが `/dev/kvm` を開けるようにする（WSL を再起動しても残るよう udev ルールで書く）。

```bash
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666"' | sudo tee /etc/udev/rules.d/99-kvm-nixbld.rules
sudo udevadm trigger --name-match=kvm
```

### ビルド

```bash
git clone https://github.com/ymat19/dotfiles ~/repos/dotfiles
cd ~/repos/dotfiles
nix build --impure --accept-flake-config -L --out-link ~/winq-image \
  .#nixosConfigurations.winq-emu.config.system.build.winqImage
```

`~/winq-image/nixos.qcow2` ができる（20GB 強）。初回はキャッシュの取得と一部のソースビルドで数十分かかる。

イメージは中身ぎりぎりの大きさで作り、Windows 側で広げる。最初から大きく（200GB など）作ると、
中身を書き込む `cptofs`（LKL）が途中で CPU 100% のまま止まった。

## 3. Windows に置いて広げる

```powershell
New-Item -ItemType Directory -Force "$env:LOCALAPPDATA\niri-vm"
Copy-Item \\wsl.localhost\Ubuntu\home\<user>\winq-image\nixos.qcow2 "$env:LOCALAPPDATA\niri-vm\disk.qcow2"
Set-ItemProperty "$env:LOCALAPPDATA\niri-vm\disk.qcow2" IsReadOnly $false
C:\WINQ-EMU\bin\qemu-img.exe resize "$env:LOCALAPPDATA\niri-vm\disk.qcow2" 200G
Copy-Item \\wsl.localhost\Ubuntu\home\<user>\repos\dotfiles\scripts\winq\start-niri-vm.ps1 "$env:LOCALAPPDATA\niri-vm\"
```

パーティションと ext4 は、VM の起動時に `boot.growPartition` と `autoResize` が広げる。

## 4. 起動する

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\niri-vm\start-niri-vm.ps1"
```

主な引数（既定値）:

| 引数 | 既定 | 内容 |
|---|---|---|
| `-Width` / `-Height` | 3440 / 1440 | niri の既定モード |
| `-Memory` / `-Cpus` | 24G / 16 | VM のメモリと vCPU |
| `-Share <フォルダ>` | なし | 9p で共有し、ゲストの `/mnt/windows` に自動マウント |
| `-Audio` | auto | 再生デバイスが無ければ `none`（下の「既知の問題」参照） |
| `-FullScreen` | なし | 全画面で起動 |

ssh は `127.0.0.1:2223`、QMP は `127.0.0.1:4445` にだけ開く。シリアル出力と QEMU のエラーは
`%LOCALAPPDATA%\niri-vm\logs\` に残る。

デスクトップ用のショートカットは、リンク先を
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\niri-vm\start-niri-vm.ps1"` にして作る。

## 5. 初回ログイン後

- ユーザー `ymat19`、初期パスワードは `nixos-configurations/winq-emu.nix` の `initialPassword`。すぐ `passwd` で変える
- GPU 転送の確認: `eglinfo -B -p surfaceless` で `virgl (...)`、`vulkaninfo --summary` で `Virtio-GPU Venus (...)` が出ればよい
- 以後の更新は VM の中で行う（イメージの作り直しは不要）

```bash
git clone https://github.com/ymat19/dotfiles ~/repos/dotfiles
cd ~/repos/dotfiles
sudo nixos-rebuild switch --flake .#winq-emu --impure
```

## 6. Windows 側の設定

### 右 Win キーを niri の Super にする

Win キーは Windows が先に取り、特に Win+L は PowerToys などのキーフックでも止められずロックされる。
そこで右 Win をドライバの段階で Menu キーに変換し、VM 内の xremap が Super に戻す。

`scripts/winq/rwin-to-menu.reg` を取り込んで再起動する（管理者権限が必要）。
Scancode Map は値ごと置き換わるので、このファイルには CapsLock → 左 Ctrl も入れてある。
他の変換を使っている場合は、それも含めて書き直すこと。

確認: Windows 上で右 Win 単押しが右クリックメニューになり、右 Win+L でロックされない。VM 内で右 Win+Q が効く。

### 日本語入力

Windows の IME が QEMU のウィンドウでキーを取らないようにし、日本語入力は VM 内の fcitx5-mozc に任せる。

1. 設定 > 時刻と言語 > 入力 > キーボードの詳細設定 で「アプリ ウィンドウごとに異なる入力方式を設定する」をオン
2. QEMU のウィンドウで IME をオフ（半角英数）にしておく

## 既知の問題

- **再生デバイスが無いと固まる**: `-audiodev sdl` で Windows に有効な再生デバイスが無いと、SDL がデバイスを開き直し続けて
  QEMU のメインループが止まり、画面も ssh も応答しなくなる。起動スクリプトの `-Audio auto` は、その場合 `none` にする。
  デバイスをつないだら VM を起動し直すと音が出る
- **画面のちらつき**: 発生することがある。未調査
- **Chromium 系のハードウェア動画デコード**: WINQ-EMU の既知の問題で、映像が黒くなったり崩れたりする。ブラウザ側でハードウェア動画デコードを切る
- **EFI ブートは使わない**: WINQ-EMU では EFI だと Vulkan が極端に遅くなるため、GRUB（BIOS）で起動している
- **ネットワーク**: QEMU の user モード（NAT）。VM の通信は Windows の経路表に従うので、Windows が VPN につながっていれば VM も VPN を通る。
  ただし Windows の NRPT（ドメインごとの DNS 振り分け）は効かないので、それに頼る名前解決は失敗しうる
- **VM の中で VM は動かない**: WHPX の中ではネストした仮想化が使えないので、libvirt 一式は外している
