# winq-emu: Windows 上で niri を動かす VM

Windows 上の WINQ-EMU（WHPX と GPU 転送に対応した QEMU のビルド）で、
このリポジトリの NixOS（niri + DMS）を VM として動かす。ホスト名は `winq-emu`。

WINQ-EMU 本家（[cmspam/winq-emu](https://github.com/cmspam/winq-emu)）は更新が止まっているので、
[Try Omarchy for Windows](https://github.com/omacom/try-omarchy-windows) が単体で配っている
WINQ-EMU ランタイム（本家 Alpha10 のソースにパッチを足して再ビルドしたもの）を使う。

- CPU は WHPX（Windows Hypervisor Platform）で `-cpu host` のまま動く
- 描画は virtio-gpu 経由で Windows の GPU に転送する（OpenGL は virgl、Vulkan は Venus）。単体 GPU が無くても CPU 内蔵 GPU で動く
- Hyper-V の VM と違って画面が CPU 描画にならないので、niri のアニメーションも実用的な速さで動く

## 構成

| ファイル | 役割 |
|---|---|
| `flake.nix` の `winq-emu` | ホスト定義。WSL 上でビルドしても `onWSL = false` に固定し、`/etc/nixos` の無い環境でも出力する |
| `hardware-configuration/winq-emu/` | QEMU ゲスト用のハードウェア設定（virtio、ラベル `nixos` のルート、起動時に自動拡張） |
| `nixos-configurations/winq-emu.nix` | VM 固有の設定、qcow2 イメージの出力（`system.build.winqImage`）、ランチャーとつなぐゲスト側のサービス |
| `modules/nixos/system/xremap.nix` | `winq-emu` のときだけ F13（`KEY_F13`）を Super に戻す |
| `scripts/winq/launcher/` | Windows 側のランチャー `niri-vm.exe`（Go）。`flake.nix` の `packages.<system>.winq-launcher` でクロスビルドする |
| `scripts/winq/guest/` | ゲスト側のクリップボード連携と再起動の通知（`winq-emu.nix` が systemd サービスにする） |
| `scripts/winq/rwin-to-f13.reg` | 右 Win を F13 に変換するレジストリ（Scancode Map） |

`scripts/winq/launcher/` と `scripts/winq/guest/` は
[Try Omarchy for Windows](https://github.com/omacom/try-omarchy-windows)（MIT License）のランチャー（`app/`）と
ゲスト側のスクリプト（`scripts/guest/`）を使う。上流は flake の入力 `try-omarchy-windows` で、URL にコミットを
固定している。ランチャーは上流のファイルをビルド時にそのまま使い、改変は `patches/`、上流の大きなファイルから
抜き出した宣言は `excerpts*.go` などに置く。抜き出しはビルド時に `tools/excerptcheck` で上流と照合する。

### 上流への追従

1. `flake.nix` の `try-omarchy-windows` の URL のコミットを上げ、`nix flake lock` する
2. `nix build .#winq-launcher` する。パッチが当たらない、または抜き出しが上流と違うとビルドが止まるので直す
3. 上流の `CHANGELOG.md` でランタイムの版が上がっていれば、1 章の zip と SHA256 を合わせて差し替える
4. Windows でクリップボード、×、VM の中からの再起動を試してから push する

## 必要なもの

- Windows 10/11（x64）。仮想化支援が有効で、ハイパーバイザが動いていること
  （メモリ整合性 / VBS が有効なら追加設定は不要。そうでなければ「Windows ハイパーバイザー プラットフォーム」を有効化して再起動）
- GPU ドライバは新しいものに更新しておく（Venus は Windows 側の Vulkan ドライバを使う）
- Nix のある x86_64 の Linux（イメージとランチャーのビルド用）。WSL2 の Ubuntu でも別の Linux 機でもよい。
  イメージのビルドには KVM が要る（ランチャーのビルドには要らない）

## 1. WINQ-EMU を入れる

Try Omarchy for Windows のリリース `runtime-v1-r27` にある `winq-emu-alpha10-portable.zip` を
`%LOCALAPPDATA%\WINQ-EMU` に展開する（インストーラは無く、展開するだけ）。以下はこの場所に置いた前提で書いている。
ユーザー領域に置くので管理者権限（UAC）は要らない。
使う版は Try Omarchy 本体が `guest-build/runtime.lock.json` で固定している版に合わせる。

```powershell
$url  = 'https://github.com/omacom/try-omarchy-windows/releases/download/runtime-v1-r27/winq-emu-alpha10-portable.zip'
$sha  = '835d3b16697aa60b257f233d2de95ced47ee866ddd6aeef97b302fa336e46d57'
$zip  = "$env:TEMP\winq-emu-portable.zip"
Invoke-WebRequest $url -OutFile $zip
if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $sha) { throw 'SHA256 が一致しない' }
Expand-Archive $zip "$env:LOCALAPPDATA\WINQ-EMU" -Force   # bin\qemu-system-x86_64.exe ができる
```

## 2. イメージとランチャーをビルドする

Nix のある x86_64 の Linux で行う。以下の例は WSL2 の Ubuntu を想定した注記を含むが、WSL は必須ではない。

### Nix

`trusted-users` はこの flake のキャッシュ（`nixConfig`）を使うのに、`kvm` 機能はイメージ作成（内部で VM を使う）に要る。
Nix が既に入っている Linux（NixOS を含む）では、この 2 つが設定されていればよい。

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm \
  --extra-conf "trusted-users = root $(whoami)" \
  --extra-conf "extra-system-features = kvm"
```

Nix のビルド用ユーザーが `/dev/kvm` を開けるようにする（再起動しても残るよう udev ルールで書く）。

```bash
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666"' | sudo tee /etc/udev/rules.d/99-kvm-nixbld.rules
sudo udevadm trigger --name-match=kvm
```

WSL を使う場合は、既定のメモリ上限（物理メモリの半分）だとイメージ作成中にページキャッシュで上限に張り付き、
WSL 全体が応答しなくなることがある。`%USERPROFILE%\.wslconfig` で上限を上げてから `wsl --shutdown` する。

```ini
[wsl2]
memory=48GB
```

### イメージ

```bash
git clone https://github.com/ymat19/dotfiles ~/repos/dotfiles
cd ~/repos/dotfiles
# 初回ログイン用のパスワードを聞かれる（ハッシュだけがイメージに入り、リポジトリには残らない）
WINQ_INITIAL_PASSWORD_HASH=$(nix run nixpkgs#mkpasswd) \
  nix build --impure --accept-flake-config -L --out-link ~/winq-image \
  .#nixosConfigurations.winq-emu.config.system.build.winqImage
```

`~/winq-image/nixos.qcow2` ができる（20GB 強）。初回はキャッシュの取得と一部のソースビルドで数十分かかる。
イメージは中身ぎりぎりの大きさなので、Windows に置いてから広げる（3 章）。

### ランチャー（niri-vm.exe）

```bash
cd ~/repos/dotfiles
nix build --accept-flake-config --out-link ~/niri-vm .#winq-launcher
```

`~/niri-vm/bin/niri-vm.exe` ができる。Go の Windows 向けクロスビルドなので KVM は要らず、
winq-emu の VM の中でもビルドできる。

## 3. Windows に置く

ビルドした Linux から Windows へファイルを持ってくる。例:

- WSL でビルドした場合: エクスプローラーや PowerShell から `\\wsl.localhost\<ディストリビューション名>\home\<user>\...` を開く
- winq-emu の VM の中でビルドした場合: Windows から `scp -P 2223 ymat19@127.0.0.1:<パス> <置き場所>`
  （`<パス>` は `readlink -f` で Nix のストアの実パスにしたもの）

置き場所（以下はこの場所に置いた前提で書いている）:

| ファイル | 置き場所 |
|---|---|
| `nixos.qcow2` | `%LOCALAPPDATA%\niri-vm\disk.qcow2` |
| `niri-vm.exe` | `%LOCALAPPDATA%\niri-vm\niri-vm.exe` |

ディスクは書き込み可能にして広げる（Nix のストアからのコピーは読み取り専用になっている）。

```powershell
New-Item -ItemType Directory -Force "$env:LOCALAPPDATA\niri-vm"
# ここで disk.qcow2 と niri-vm.exe を上の場所にコピーしておく
Set-ItemProperty "$env:LOCALAPPDATA\niri-vm\disk.qcow2" IsReadOnly $false
Set-ItemProperty "$env:LOCALAPPDATA\niri-vm\niri-vm.exe" IsReadOnly $false
& "$env:LOCALAPPDATA\WINQ-EMU\bin\qemu-img.exe" resize "$env:LOCALAPPDATA\niri-vm\disk.qcow2" 200G
```

パーティションと ext4 は、VM の起動時に `boot.growPartition` と `autoResize` が広げる。

ランチャーを更新するときは、VM を止めてから `niri-vm.exe` を置き換える（動いている間は置き換えられない）。

## 4. 起動する

`%LOCALAPPDATA%\niri-vm\niri-vm.exe` を実行する（ダブルクリックでよい）。デスクトップ用のショートカットは、
リンク先を `"%LOCALAPPDATA%\niri-vm\niri-vm.exe"`（引数を付けるならその後ろ）にして作る。
GUI のプログラムなのでコンソールの窓は出ない。

主な引数（既定値）:

| 引数 | 既定 | 内容 |
|---|---|---|
| `-width` / `-height` | 3440 / 1440 | niri の既定モード |
| `-memory` / `-cpus` | 32G / 20 | VM のメモリと vCPU |
| `-gpu-hostmem` | 4G | virtio-gpu の blob 用ホストメモリ |
| `-share <フォルダ>` | なし | 9p で共有する（ゲストは `/mnt/windows` に自動マウントする設定） |
| `-audio` | auto | `auto` / `sdl` / `dsound` / `none`。auto は有効な再生デバイスが無ければ `none`。デバイスをつないだらランチャーを起動し直す |
| `-dns-search <a,b>` | Windows の検索リスト | VM に DHCP で渡す DNS の検索リスト。`-dns-search=` で渡さない（下の「ネットワーク」参照） |
| `-fullscreen` | なし | 全画面で起動 |
| `-ssh-port` | 2223 | ゲストの ssh を転送する `127.0.0.1` のポート |
| `-qmp-port` | 0（開かない） | QMP を `127.0.0.1` の TCP でも開く（下の「QMP」参照） |
| `-disk` / `-winq-dir` | `%LOCALAPPDATA%\niri-vm\disk.qcow2` / `%LOCALAPPDATA%\WINQ-EMU` | ディスクイメージと WINQ-EMU の場所 |

例: `niri-vm.exe -fullscreen`、`niri-vm.exe -width 1920 -height 1080`

ssh は `127.0.0.1:2223` にだけ開く。ランチャーのログ（`launcher.log`）、シリアル出力（`serial.log`）、
QEMU のエラー（`qemu-stderr.log`）は `%LOCALAPPDATA%\niri-vm\logs\` に残る。

### ランチャーがすること

Try Omarchy for Windows のランチャーと同じ方式で、次のことをする。

- **クリップボード連携**: テキスト、PNG 画像、ファイル/フォルダを Windows と VM の間で双方向にコピーできる。
  VM 側はユーザーサービス `clipboard-bridge` が QEMU の user ネットワーク越しに `10.0.2.2` のランチャーにつなぐ。
  Windows に貼り付けたファイルは `%LOCALAPPDATA%\niri-vm\Clipboard\` に置かれる
- **閉じるときの確認**: QEMU のウィンドウの × や Alt+F4 では即座に止めず、確認してから ACPI の電源ボタン
  （QMP の `system_powerdown`）で VM の中の OS を正しくシャットダウンさせる
- **VM の再起動**: QEMU を `-no-reboot` で動かし、VM の中で再起動すると QEMU がいったん終わるので、ランチャーが起動し直す。
  電源オフならランチャーも終わる。どちらかは QMP の `SHUTDOWN` イベントで決め、届かなかったときは
  VM のシャットダウン時にサービス `winq-reboot-notify` が送る通知で補う
- **スリープの無効化**: S3/S4 を無効にして、VM がサスペンドしてウィンドウが固まらないようにする
- **空きメモリの返却**: ランタイムが対応していれば（`provenance\sources.lock.json` にパッチ
  `0015-reclaim-free-guest-pages-on-whpx` がある）、virtio-balloon の free page reporting で VM が空けたメモリを Windows に返す

### QMP

ランチャーは QMP を `%TEMP%\NiriVMIPC\` の unix ソケット（Windows の AF_UNIX）で開く。外から使うときは `tools.sock` につなぐ。
既定で TCP に開かないのは、VM の中から `10.0.2.2` 経由でホストの `127.0.0.1` に届くため（Try Omarchy と同じ）。
Try Omarchy と同じく、起動直後の数秒は QMP に接続しないこと（WHPX の QEMU が止まることがある）。

## 5. 初回ログイン後

- ユーザー `ymat19`、パスワードはイメージのビルド時に入力したもの
- ssh は鍵でだけ入れる。Windows の公開鍵を VM の `~/.ssh/authorized_keys` に入れておく
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
そこで右 Win をドライバの段階で F13 に変換し、VM 内の xremap が Super に戻す。

`scripts/winq/rwin-to-f13.reg` を取り込んで再起動する（管理者権限が必要）。
Scancode Map は値ごと置き換わるので、このファイルには CapsLock → 左 Ctrl も入れてある。
他の変換を使っている場合は、それも含めて書き直すこと。

確認: Windows 上で右 Win を押しても何も起きず、右 Win+L でロックされない。VM 内で右 Win+Q が効く。

### 右 Win+Tab で仮想デスクトップを切り替える

Windows の仮想デスクトップを 2 枚にし、左を Windows の作業用、右を VM（全画面）にする。
ランチャーが動いている間、右 Win+Tab で 2 枚を行き来する（VM が前面なら左へ、そうでなければ右へ）。
Tab は VM にも Windows にも渡らない。niri の Mod+Tab（直近のウィンドウ切り替え）は winq-emu では割り当てていない。

## 既知の問題

- **画面が固まることがある**: 使用中に画面が更新されなくなったことがある。VM の中で、画面の更新が GPU の処理の
  完了待ち（`drm_atomic_helper_wait_for_fences`）から戻らなくなっていた。契機と原因は調査中
- **画面のちらつき**: 発生することがある。未調査
- **Try Omarchy for Windows と同時には起動できない**: ランチャーは Try Omarchy と同じ `127.0.0.1` のポート
  （4448・4449 がクリップボード、4450 が再起動の通知、4452 がファイル転送）を使う。ゲスト側のスクリプトがこの番号を決め打ちしているため
- **ネットワーク**: QEMU の user モード（NAT）。VM の通信は Windows の経路表に従うので、Windows が VPN につながっていれば VM も VPN を通る。
  Windows の NRPT（ドメインごとの DNS 振り分け）は効かない。
  DNS の検索リストは、ランチャーが Windows の値（`(Get-DnsClientGlobalSetting).SuffixSearchList`）を読んで
  DHCP（オプション 119）で VM に渡すので、DNS に登録された社内ホストは短い名前でも引ける
  （値はランチャーの起動時に固定。VM の中での再起動では読み直さない）。
  NetBIOS や LLMNR でしか見つからない名前は VM からは引けない
