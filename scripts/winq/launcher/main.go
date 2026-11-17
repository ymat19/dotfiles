// niri-vm.exe: WINQ-EMU（Try Omarchy for Windows が配っている QEMU ランタイム）で
// winq-emu ホスト（niri）の VM を起動し、見張るランチャー。旧 scripts/winq/start-niri-vm.ps1 の置き換え。
//
// 起動の監視・クリップボード連携・閉じるときの確認・Windows の終了時の停止は
// Try Omarchy for Windows（https://github.com/omacom/try-omarchy-windows、MIT License）の
// app/ のコードをそのまま、または抜き出して使っている（各ファイルの見出しを参照）。
// このファイルは独自のコード: 引数、QEMU の引数の組み立て（旧 ps1 の構成に Try Omarchy の
// window-close=off・S3/S4 無効・-no-reboot・free page reporting・QMP の unix ソケットを足したもの）、
// 起動の順番。
//
// イメージの作り方は docs/winq-emu.md を参照。

//go:build windows

package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

type config struct {
	qemu, disk string
	// vmDir はログの置き場所（ディスクの隣の logs\）。Try Omarchy から持ち込んだ関数
	// （qemuStartupFailureTail、audioUnavailable）がここの qemu-stderr.log を読む。
	vmDir string
	// qmpDir は QMP の unix ソケットの置き場所（qmp_control_windows.go）。
	qmpDir     string
	memory     string
	cpus       int
	gpuHostMem string
	width      int
	height     int
	sshPort    int
	qmpPort    int
	share      string
	// audio は今回の起動で使う QEMU の audiodev（sdl / dsound / none）。
	audio      string
	dnsSearch  []string
	fullscreen bool
}

func main() {
	local := os.Getenv("LOCALAPPDATA")
	disk := flag.String("disk", filepath.Join(local, "niri-vm", "disk.qcow2"), "VM のディスクイメージ（qcow2）")
	// 管理者権限なしで置けるユーザー領域（貸与端末で UAC を要らなくするため）
	winqDir := flag.String("winq-dir", filepath.Join(local, "WINQ-EMU"), "WINQ-EMU ランタイムを展開したフォルダ")
	memory := flag.String("memory", "32G", "VM のメモリ（QEMU の -m）")
	cpus := flag.Int("cpus", 20, "VM の vCPU 数")
	gpuHostMem := flag.String("gpu-hostmem", "4G", "virtio-gpu の blob 用ホストメモリ")
	// 解像度は niri が選ぶ既定モードになる。ウィンドウを動かしても変わらない。
	width := flag.Int("width", 3440, "niri の既定モードの幅")
	height := flag.Int("height", 1440, "niri の既定モードの高さ")
	sshPort := flag.Int("ssh-port", 2223, "ゲストの ssh を転送する 127.0.0.1 のポート")
	qmpPort := flag.Int("qmp-port", 0, "外部ツール用に QMP を開く 127.0.0.1 の TCP ポート（0 で開かない。docs/winq-emu.md を参照）")
	// Windows のフォルダを 9p で渡す（ゲストでは /mnt/windows に自動マウント）
	share := flag.String("share", "", "9p で共有する Windows のフォルダ")
	// auto: 有効な再生デバイスがあれば sdl、無ければ none（Try Omarchy と同じ）。
	// どの値でも、QEMU が音声デバイスを開けずに起動直後に落ちたら sdl → dsound → none で
	// 起動し直す（Try Omarchy と同じ）。
	audio := flag.String("audio", "auto", "auto / sdl / dsound / none")
	// VM に DHCP で渡す DNS の検索リスト。既定は Windows の検索リスト（ドメイン参加や VPN で配られたもの）。
	// これが無いと、Windows では短いホスト名で引けるサーバーが、VM では完全な名前でしか引けない。
	// 値は VM の起動時に固定される。
	dnsSearch := flag.String("dns-search", "", "VM に渡す DNS の検索リスト（カンマ区切り。指定しなければ Windows の検索リスト、空文字で渡さない）")
	fullscreen := flag.Bool("fullscreen", false, "全画面で起動する")
	flag.Parse()
	explicit := map[string]bool{}
	flag.Visit(func(f *flag.Flag) { explicit[f.Name] = true })

	cfg := &config{
		qemu: filepath.Join(*winqDir, "bin", "qemu-system-x86_64.exe"), disk: *disk,
		memory: *memory, cpus: *cpus, gpuHostMem: *gpuHostMem, width: *width, height: *height,
		sshPort: *sshPort, qmpPort: *qmpPort, share: *share, fullscreen: *fullscreen,
	}
	if _, err := os.Stat(cfg.qemu); err != nil {
		fatal(fmt.Sprintf("WINQ-EMU が見つからない: %s（docs/winq-emu.md の手順で winq-emu-alpha10-portable.zip を展開する）", cfg.qemu))
	}
	if _, err := os.Stat(cfg.disk); err != nil {
		fatal(fmt.Sprintf("ディスクイメージが見つからない: %s", cfg.disk))
	}
	if cfg.share != "" {
		if info, err := os.Stat(cfg.share); err != nil || !info.IsDir() {
			fatal(fmt.Sprintf("共有フォルダが見つからない: %s", cfg.share))
		}
	}
	switch *audio {
	case "auto":
		cfg.audio = autoAudioBackend()
	case "sdl", "dsound", "none":
		cfg.audio = *audio
	default:
		fatal(fmt.Sprintf("-audio は auto / sdl / dsound / none のどれか: %s", *audio))
	}

	cfg.vmDir = filepath.Join(filepath.Dir(cfg.disk), "logs")
	if err := os.MkdirAll(cfg.vmDir, 0o755); err != nil {
		fatal(fmt.Sprintf("ログのフォルダを作れない: %s: %v", cfg.vmDir, err))
	}
	if f, err := os.OpenFile(filepath.Join(cfg.vmDir, "launcher.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644); err == nil {
		logFile = f
		defer f.Close()
	}
	logf("---- starting ----")

	if explicit["dns-search"] {
		cfg.dnsSearch = splitList(*dnsSearch)
	} else {
		cfg.dnsSearch = windowsDNSSearchList()
	}
	logf("niri VM: %s  mem=%s cpus=%d %dx%d  audio=%s  dnssearch=%s  ssh=127.0.0.1:%d",
		cfg.disk, cfg.memory, cfg.cpus, cfg.width, cfg.height, cfg.audio, strings.Join(cfg.dnsSearch, " "), cfg.sshPort)

	// Try Omarchy の起動順（main.go）に合わせる: フック・確認ダイアログ・クリップボード、
	// ゲストの再起動通知を先に用意してから QEMU を起動する。クリップボードのポートの確保は
	// 二重起動の検査を兼ねる。
	runClipboardBridge()
	runLifecycleListener()
	// Try Omarchy と同じく、QEMU の SDL にキーボードを捕まえさせない。捕まえると SDL が
	// システム全体のキーボードフックを入れ、ランチャーのフックより前に入ってキーを取る（右 Win+Tab の
	// 仮想デスクトップ切り替えが送るキーや、Tab を離した入力が届かなくなる）。
	// WINQ-EMU r27 の QEMU は上流のパッチ 0020-allow-external-sdl-keyboard-hook で捕まえる設定を上書き
	// 優先で決めるので、SDL_GRAB_KEYBOARD だけでは止まらず、OMARCHY_SDL_EXTERNAL_KEYBOARD_HOOK=1 が要る
	// （上流の app/main.go・app/qemu.go と同じ。r27 の provenance/sources.lock.json にパッチがある）。
	os.Setenv("SDL_GRAB_KEYBOARD", "0")
	os.Setenv("OMARCHY_SDL_EXTERNAL_KEYBOARD_HOOK", "1")
	runSessionWindow()
	go runWinKeyHook()
	go runCloseGuard()

	for relaunch := supervise(cfg); relaunch; relaunch = supervise(cfg) {
	}
	logf("---- exiting ----")
}

// buildQemuArgs は旧 start-niri-vm.ps1 の引数に、Try Omarchy の buildQemuArgs（app/qemu.go）から
// 次を足したもの: window-close=off、S3/S4 の無効化、-no-reboot、QMP の unix ソケット、
// free page reporting。理由のコメントは元のものを残している。
func buildQemuArgs(cfg *config) []string {
	// DHCP のオプション 119（ドメイン検索リスト）として渡す。ゲストの NetworkManager が resolv.conf の search に入れる。
	netdev := fmt.Sprintf("user,id=net0,hostfwd=tcp:127.0.0.1:%d-:22", cfg.sshPort)
	for _, d := range cfg.dnsSearch {
		netdev += ",dnssearch=" + qemuOptionValue(d)
	}
	args := []string{
		"-name", "niri",
		"-machine", "q35,accel=whpx",
		"-cpu", "host",
		"-m", cfg.memory,
		"-smp", fmt.Sprint(cfg.cpus),
		"-drive", "file=" + qemuOptionValue(cfg.disk) + ",format=qcow2,if=virtio,discard=unmap",
		// 解像度は niri が選ぶ既定モードになる。ウィンドウを動かしても変わらない。
		"-device", fmt.Sprintf("virtio-vga-gl,blob=on,hostmem=%s,venus=on,xres=%d,yres=%d", cfg.gpuHostMem, cfg.width, cfg.height),
		// window-close=off: the X must not hard-kill a running OS; the
		// close guard intercepts the click and confirms + shuts down
		// gracefully instead (closeguard.go).
		"-display", sdlDisplay(true, false),
		"-device", "virtio-keyboard-pci",
		"-device", "virtio-tablet-pci",
		// none でも virtio-sound 自体は置く（ゲストの PipeWire は audiodev が無いと固まる）
		"-audiodev", cfg.audio + ",id=snd",
		"-device", "virtio-sound-pci,audiodev=snd",
		// romfile= で iPXE を外す（直接ディスクから起動するので不要、起動が少し速くなる）
		"-device", "virtio-net-pci,netdev=net0,romfile=",
		"-netdev", netdev,
		"-device", "virtio-rng-pci",
		// The guest must not sleep: a suspended VM leaves the window frozen
		// with no way back from the keyboard, and Omarchy's power menu
		// offers suspend whenever the kernel advertises it. With S3 and S4
		// off the kernel reports no such state and systemd refuses cleanly.
		"-global", "ICH9-LPC.disable_s3=1", "-global", "ICH9-LPC.disable_s4=1",
		"-serial", "file:" + qemuOptionValue(filepath.Join(cfg.vmDir, "serial.log")),
		// In-guest reboot/poweroff wedges upstream WHPX (vCPUs never return
		// from system reset). Exit instead; the supervisor relaunches on reset.
		"-no-reboot",
	}
	// Power holds its own Windows monitor across sleep. Tools, forwarding and
	// supervisor controls stay available even when automatic resume fails.
	for _, role := range platformQMPControlRoles() {
		args = append(args, "-qmp", "unix:"+qemuOptionValue(filepath.Join(cfg.qmpDir, qmpControlName(role)))+",server=on,wait=off")
	}
	// 外部ツール用の TCP の QMP。ゲストからも 10.0.2.2 で届いてしまうので既定では開かない
	// （Try Omarchy が QMP を unix ソケットだけにしている理由。app/qmp_control.go の冒頭を参照）。
	if cfg.qmpPort > 0 {
		args = append(args, "-qmp", fmt.Sprintf("tcp:127.0.0.1:%d,server=on,wait=off", cfg.qmpPort))
	}
	// The bundled r19 runtime replaces reported free pages with demand-zero
	// Windows backing before acknowledging Linux. Earlier Windows QEMU builds
	// cannot discard these pages and spam errors when reporting is enabled.
	if runtimeHasPatch(cfg.qemu, "patches/qemu/0015-reclaim-free-guest-pages-on-whpx.patch") {
		args = append(args, "-device", "virtio-balloon-pci,free-page-reporting=on")
	}
	if cfg.share != "" {
		args = append(args, "-virtfs", "local,path="+qemuOptionValue(cfg.share)+",mount_tag=hostshare,security_model=none")
	}
	if cfg.fullscreen {
		args = append(args, "-full-screen")
	}
	return args
}

// autoAudioBackend は旧 ps1 の -Audio auto と同じく、有効な再生デバイスが無ければ none にする。
// デバイスの列挙は Try Omarchy の listAudioEndpoints（audio_endpoints_windows.go）を使う。
// 列挙そのものに失敗したら sdl にして、起動直後に落ちたときの切り替えに任せる。
func autoAudioBackend() string {
	endpoints, err := listAudioEndpoints()
	if err != nil {
		logf("audio: could not list playback devices, trying sdl: %v", err)
		return "sdl"
	}
	if len(endpoints.Output) == 0 {
		return "none"
	}
	return "sdl"
}

// windowsDNSSearchList は旧 ps1 の既定値 (Get-DnsClientGlobalSetting).SuffixSearchList と同じ値を、
// 同じコマンドで読む。GUI のプログラムからでもコンソールの窓が出ないように起動する。
func windowsDNSSearchList() []string {
	powershell := filepath.Join(os.Getenv("SystemRoot"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
	cmd := exec.Command(powershell, "-NoProfile", "-NonInteractive", "-Command", "(Get-DnsClientGlobalSetting).SuffixSearchList")
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000} // CREATE_NO_WINDOW
	out, err := cmd.Output()
	if err != nil {
		logf("dns search: could not read the Windows search list: %v", err)
		return nil
	}
	return splitList(strings.ReplaceAll(string(out), "\r\n", ","))
}

func splitList(s string) []string {
	var list []string
	for _, v := range strings.FieldsFunc(s, func(r rune) bool { return r == ',' || r == '\n' }) {
		if v = strings.TrimSpace(v); v != "" {
			list = append(list, v)
		}
	}
	return list
}
