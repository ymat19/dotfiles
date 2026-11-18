---
name: windows-hyperv
description: >-
  winq-emu の VM の中から、ホストの Windows の Hyper-V を PowerShell で操作する。
  Hyper-V の VM の一覧・作成・起動・停止・削除・チェックポイント・スイッチなどを扱うときに使う。
  Triggers: "Hyper-V", "Get-VM", "Windows の VM", "ホストの VM を作って", "Hyper-V マネージャー".
---

# Windows の Hyper-V を操作する

この VM（winq-emu）のホストの Windows に ssh し、Hyper-V の PowerShell モジュールで操作する。
Hyper-V マネージャーの GUI は使えないので、同じことを PowerShell のコマンドレットで行う。

## 接続

ssh の別名 `windows-host` で入る。ログイン先のシェルは Windows PowerShell 5.1。

```bash
ssh windows-host 'Get-VM | Select-Object Name,State,CPUUsage,MemoryAssigned,Uptime | Format-Table -AutoSize'
```

- 出力の文字化けを避けるため、日本語を含みうるコマンドの先頭に `[Console]::OutputEncoding=[Text.Encoding]::UTF8;` を付ける。
- 複数行のスクリプトは引数に詰めず、標準入力で渡す:
  `ssh windows-host 'powershell -NoProfile -Command -' < script.ps1`
- 接続時の post-quantum の警告（`** WARNING: ...`）は無害。必要なら `2>/dev/null` で落とす。
- `$` は bash 側で展開されないよう、コマンド全体を単一引用符で囲む。
- 結果を機械的に読むときは `| ConvertTo-Json -Depth 3` を付ける。

## よく使うコマンドレット

| 目的 | コマンド |
|---|---|
| 一覧 | `Get-VM` |
| 作成 | `New-VM -Name <名前> -Generation 2 -MemoryStartupBytes 4GB -NewVHDPath <パス> -NewVHDSizeBytes 64GB -SwitchName <スイッチ>` |
| 起動・停止 | `Start-VM` / `Stop-VM`（ゲストにシャットダウンを依頼） / `Stop-VM -TurnOff`（電源断） |
| 構成の変更 | `Set-VM`、`Set-VMProcessor`、`Set-VMMemory`、`Add-VMHardDiskDrive`、`Set-VMDvdDrive` |
| チェックポイント | `Checkpoint-VM`、`Get-VMSnapshot`、`Restore-VMSnapshot` |
| ネットワーク | `Get-VMSwitch`、`Get-VMNetworkAdapter` |
| ディスク | `Get-VHD`、`New-VHD`、`Resize-VHD` |

既定の VM・VHD の置き場所は `Get-VMHost | Select-Object VirtualMachinePath,VirtualHardDiskPath` で調べる。
パスやスイッチ名は推測せず、必ずこれらで実際の値を確かめてから使う。

## 守ること

- このホストの Hyper-V の VM・ディスク・チェックポイントはすべて検証用。作成・変更・電源断・削除・巻き戻しは、
  ユーザーに確認せずに実行する。作業で作ったものは、終わったら片付ける。
- この VM 自身は Hyper-V の VM ではない（WINQ-EMU の QEMU が Windows Hypervisor Platform で動かしている）。
  `Get-VM` には出てこないので、この VM を操作しようとしない。
- 入れ子の仮想化はしない。作る Hyper-V の VM は Windows 上で動き、この VM の中では動かない。

## つながらないとき

Windows 側の前提（OpenSSH サーバー、Hyper-V を操作できるローカルユーザー、鍵）は
dotfiles の `docs/winq-emu.md` の「VM から Hyper-V を操作する」に書いてある。
`ssh -v windows-host` で、接続拒否・鍵の不一致・ホスト鍵の不一致のどれかを見分けてから、その節の手順で直す。
