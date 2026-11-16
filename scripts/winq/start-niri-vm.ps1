<#
.SYNOPSIS
  WINQ-EMU で winq-emu ホスト（niri）の VM を起動する。

.DESCRIPTION
  C:\WINQ-EMU\launch-vm.bat と同じ構成（WHPX + -cpu host、BIOS ブート、
  Venus/virgl の virtio-vga-gl）に、niri 向けの調整を足したもの:
    - 解像度を virtio-gpu の既定モードとして渡す（-Width/-Height、既定 3440x1440）
    - virtio の keyboard/tablet（絶対座標なのでマウス捕獲が要らない）
    - ssh・QMP は 127.0.0.1 にだけ開く
    - serial をログに落とす（起動しないときの調査用）

  イメージの作り方（WSL など Nix のある Linux で）:
    nix build --impure .#nixosConfigurations.winq-emu.config.system.build.winqImage
  できた result/nixos.qcow2 を -Disk の場所へコピーし、書き込み可能にする。

.EXAMPLE
  .\start-niri-vm.ps1 -FullScreen
.EXAMPLE
  .\start-niri-vm.ps1 -Width 1920 -Height 1080 -Share D:\work
#>
param(
  [string]$Disk = (Join-Path $env:LOCALAPPDATA 'niri-vm\disk.qcow2'),
  [string]$WinqDir = 'C:\WINQ-EMU',
  [string]$Memory = '24G',
  [int]$Cpus = 16,
  [string]$GpuHostMem = '4G',
  [int]$Width = 3440,
  [int]$Height = 1440,
  [int]$SshPort = 2223,
  [int]$QmpPort = 4445,
  # Windows のフォルダを 9p で渡す（ゲストでは /mnt/windows に自動マウント）
  [string]$Share,
  # auto: 有効な再生デバイスがあれば sdl、無ければ none。
  # 再生デバイスが無いのに sdl にすると、SDL の WASAPI が開けないデバイスを
  # 再試行し続けて QEMU のメインループが止まり、画面・ssh ごと固まる。
  [ValidateSet('auto', 'sdl', 'dsound', 'none')]
  [string]$Audio = 'auto',
  [switch]$FullScreen
)

$ErrorActionPreference = 'Stop'

$qemu = Join-Path $WinqDir 'bin\qemu-system-x86_64.exe'
if (-not (Test-Path $qemu)) { throw "WINQ-EMU が見つからない: $qemu" }
if (-not (Test-Path $Disk)) { throw "ディスクイメージが見つからない: $Disk" }

$logDir = Join-Path (Split-Path $Disk -Parent) 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null

# QEMU のオプション値ではカンマが区切りなので、パス中のカンマは二重にする
function Escape-QemuValue([string]$v) { $v.Replace(',', ',,') }

if ($Audio -eq 'auto') {
  $active = Get-PnpDevice -Class AudioEndpoint -Status OK -ErrorAction SilentlyContinue
  $Audio = if ($active) { 'sdl' } else { 'none' }
}

$qemuArgs = @(
  '-name', 'niri'
  '-machine', 'q35,accel=whpx'
  '-cpu', 'host'
  '-m', $Memory
  '-smp', "$Cpus"
  '-drive', "file=$(Escape-QemuValue $Disk),format=qcow2,if=virtio,discard=unmap"
  # 解像度は niri が選ぶ既定モードになる。ウィンドウを動かしても変わらない。
  '-device', "virtio-vga-gl,blob=on,hostmem=$GpuHostMem,venus=on,xres=$Width,yres=$Height"
  '-display', 'sdl,gl=on'
  '-device', 'virtio-keyboard-pci'
  '-device', 'virtio-tablet-pci'
  # none でも virtio-sound 自体は置く（ゲストの PipeWire は audiodev が無いと固まる）
  '-audiodev', "$Audio,id=snd"
  '-device', 'virtio-sound-pci,audiodev=snd'
  # romfile= で iPXE を外す（直接ディスクから起動するので不要、起動が少し速くなる）
  '-device', 'virtio-net-pci,netdev=net0,romfile='
  '-netdev', "user,id=net0,hostfwd=tcp:127.0.0.1:$SshPort-:22"
  '-device', 'virtio-rng-pci'
  '-serial', "file:$(Escape-QemuValue (Join-Path $logDir 'serial.log'))"
  '-qmp', "tcp:127.0.0.1:$QmpPort,server=on,wait=off"
)
if ($Share) {
  if (-not (Test-Path $Share -PathType Container)) { throw "共有フォルダが見つからない: $Share" }
  $qemuArgs += '-virtfs', "local,path=$(Escape-QemuValue $Share),mount_tag=hostshare,security_model=none"
}
if ($FullScreen) { $qemuArgs += '-full-screen' }

Write-Host "niri VM: $Disk  mem=$Memory cpus=$Cpus ${Width}x$Height  audio=$Audio  ssh=127.0.0.1:$SshPort"
& $qemu @qemuArgs 2> (Join-Path $logDir 'qemu-stderr.log')
if ($LASTEXITCODE -ne 0) {
  Write-Warning "QEMU が終了コード $LASTEXITCODE で終わった。$logDir の qemu-stderr.log と serial.log を確認すること。"
}
