// Try Omarchy for Windows（https://github.com/omacom/try-omarchy-windows、MIT License）から
// 持ち込んだファイルが参照するが、このランチャーには持ち込まない機能の最小の置き換え。
// 元の実装の場所は各ブロックの前に書いている。ここは独自のコード。

//go:build windows

package main

import (
	"fmt"
	"os"
	"regexp"
	"runtime"
	"sync/atomic"
	"syscall"
	"time"
	"unsafe"
)

// 元: app/main.go の appTitle。ダイアログの題名に使う。
const appTitle = "niri VM"

// ---- 文言（元: app/ui_messages.go と app/ui-locales/*.json） ----
// 元は言語ごとの JSON を埋め込んで Windows の表示言語で選ぶ。ここでは使うキーだけを日本語で持つ。
// 知らないキーはキー名をそのまま返す（元は panic）。

var uiMessages = map[string]string{
	"error.move.data_stream":               "{path} に追加のデータストリームがある",
	"error.transfer.clipboard_limit":       "コピーしたファイルがクリップボードの上限（16 MiB）を超えている。共有フォルダを使うこと",
	"error.transfer.clipboard_paths_limit": "コピーしたファイルのパスが多すぎるか長すぎる。数を減らすか共有フォルダを使うこと",
	"error.transfer.entry_limit":           "転送できるのは 1〜{count} 項目",
	"error.transfer.file_name":             "Windows と Linux の間で転送できないファイル名がある",
	"error.transfer.new_destination":       "新しい転送先フォルダを選ぶこと",
	"error.transfer.new_folder":            "新しいフォルダを選ぶこと",
	"error.transfer.special_files":         "リンクや特殊ファイルは共有フォルダ経由でコピーすること",
	"error.transfer.storage_outside":       "転送用の置き場所は選んだフォルダの外にある必要がある",
	"fatal.already_running":                "niri VM のランチャーが既に動いているようだ（ポート {port} が使用中）。",
	"fatal.file_transfers":                 "ファイル転送の準備に失敗した: {error}",
	"fatal.port.file_transfer":             "ファイル転送用のポート {port} が使用中。",
	"fatal.port.lifecycle":                 "ゲストの再起動通知用のポート {port} が使用中。",
	"fatal.qemu.start":                     "QEMU を起動できなかった: {error}",
	"fatal.qemu.exited":                    "QEMU が起動直後に終了した。{folder} の qemu-stderr.log と serial.log を確認すること。",
	"fatal.qemu.unhealthy":                 "QEMU が {count} 回続けて応答しなかった。{folder} の qemu-stderr.log と serial.log を確認すること。",
	"fatal.vm_controls":                    "QEMU の制御用ソケットを用意できなかった: {error}",
	"progress.amount":                      "{label}: {done} / {total} MiB",
	"shutdown.confirm":                     "VM をシャットダウンする？\n\nVM の中で保存していないものは失われる。",
	"shutdown.unacknowledged":              "VM がシャットダウンの要求に応答しなかった。VM のウィンドウを確認してからやり直すこと。\n\n{error}",
	"shutdown.windows_reason":              "niri VM を安全にシャットダウンしている",
	"transfer.failed":                      "ファイルを転送できなかった。\n\n{error}",
	"transfer.from_omarchy_failed":         "VM からファイルをコピーできなかった。\n\n{error}",
	"transfer.phase.cancelled":             "転送を取り消した",
	"transfer.phase.failed":                "転送が終わらなかった",
	"transfer.phase.no_space":              "転送先の空きが足りない",
	"transfer.phase.placing":               "ファイルを配置している",
	"transfer.phase.preparing":             "ファイルを準備している",
	"transfer.phase.received":              "ファイルを受け取った",
	"transfer.phase.receiving":             "ファイルを受け取っている",
	"transfer.phase.sending":               "ファイルを送っている",
	"transfer.phase.sent":                  "ファイルを送った",
	"transfer.preparing_to_omarchy":        "VM に送るファイルを準備している",
	"transfer.receiving_from_omarchy":      "VM からファイルを受け取っている",
}

var uiPlaceholder = regexp.MustCompile(`\{[a-z][a-z0-9_]*\}`)

func uiText(key string) string {
	if message, ok := uiMessages[key]; ok {
		return message
	}
	return key
}

func uiTextWith(key string, values map[string]string) string {
	return uiPlaceholder.ReplaceAllStringFunc(uiText(key), func(placeholder string) string {
		if value, ok := values[placeholder[1:len(placeholder)-1]]; ok {
			return value
		}
		return placeholder
	})
}

// 元: app/ui_messages.go の uiError / catalogError（無改変）。
func uiError(text string, cause error) error { return catalogError{text: text, cause: cause} }

type catalogError struct {
	text  string
	cause error
}

func (e catalogError) Error() string { return e.text }
func (e catalogError) Unwrap() error { return e.cause }

// ---- ログ（元: app/main.go の logf / fatal） ----
// 元は shell.log。ここではディスクの隣の logs\launcher.log（main.go が開く）。

var logFile *os.File

func logf(format string, a ...any) {
	line := fmt.Sprintf("%s %s", time.Now().Format("2006-01-02 15:04:05"), fmt.Sprintf(format, a...))
	if logFile != nil {
		fmt.Fprintln(logFile, line)
	}
}

// 元の fatal は起動画面（uiDone）を閉じてからダイアログを出す。起動画面は持ち込んでいない。
func fatal(msg string) {
	logf("FATAL %s", msg)
	errorBox(msg)
	os.Exit(1)
}

// ---- ファイル転送の失敗と進捗（元: app/tray_windows.go の reportTransferError、
// app/transfer_progress_windows.go の showTransferProgress） ----

var transferErrorDialog atomic.Bool

// 元はトレイの通知を出し、出せなければダイアログにする。トレイは持ち込んでいないので
// 元の代替経路（同時に 1 つだけのダイアログ）だけを使う。
func reportTransferError(err error) {
	logf("file transfer: %v", err)
	message := uiTextWith("transfer.failed", map[string]string{"error": err.Error()})
	if transferErrorDialog.CompareAndSwap(false, true) {
		go func() { defer transferErrorDialog.Store(false); infoBox(message) }()
	}
}

func infoBox(text string) {
	msgBox(text, mbIconInfo)
}

// 元は 2 秒を超える転送に進捗と取り消しボタンの小さなウィンドウを出す。ここではログに出すだけ。
func showTransferProgress(progress *transferProgress) {
	select {
	case <-progress.done:
		return
	case <-time.After(2 * time.Second):
	}
	last := ""
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		if text, _ := progress.text.Load().(string); text != last {
			logf("transfer: %s", text)
			last = text
		}
		select {
		case <-progress.done:
			logf("transfer: finished")
			return
		case <-ticker.C:
		}
	}
}

// ---- 持ち込まない機能の状態（参照されるが、ここでは常に既定のまま） ----

// 元: app/clipboard_bridge.go の dropRequests の要素型（app/file_drop.go）。ドロップは持ち込まない。
type droppedFiles struct {
	paths  []string
	point  []int
	cursor [2]int32
}

// 元: app/boot_curtain_windows.go。起動中に QEMU のウィンドウを隠す幕。持ち込まない。
var curtainUp atomic.Bool

// 元: app/update_windows.go。自動更新は持ち込まない。closeguard.go が書き込むだけ。
var intentionalUpdateQuit atomic.Bool

func cancelBackgroundUpdate() {}

// 元: app/compositor_health.go。ゲストのコンポジタの応答監視は持ち込まない。
type compositorHealthShim struct{}

func (compositorHealthShim) stop() {}

var guestCompositorHealth compositorHealthShim

// 元: app/open_url など。lifecycle.go の open-url 行は fromSameUser=nil で先に捨てるので呼ばれない。
func parseOpenURLLine(string) (string, bool) { return "", false }

// ---- Windows のサインアウト・再起動・シャットダウンを受けるウィンドウ ----
// 元: app/tray_windows.go の startTray が作るトレイ用の隠しウィンドウが WM_QUERYENDSESSION /
// WM_ENDSESSION を受けて closeguard.go の queryEndSession / finishEndSession を呼ぶ。
// トレイは持ち込まないので、その 2 つのメッセージだけを処理する隠しのトップレベルウィンドウを作る
// （メッセージ専用ウィンドウには WM_QUERYENDSESSION が届かない）。

func runSessionWindow() {
	go func() {
		// ウィンドウのメッセージは作ったスレッドに届く。
		runtime.LockOSThread()
		hInst, _, _ := procGetModuleHandleW.Call(0)
		className, _ := syscall.UTF16PtrFromString("NiriVMSession")
		wndProc := syscall.NewCallback(func(window, message, wParam, lParam uintptr) uintptr {
			switch message {
			case 0x0011: // WM_QUERYENDSESSION
				queryEndSession(window)
				return 1
			case 0x0016: // WM_ENDSESSION
				finishEndSession(window, wParam != 0)
				return 0
			}
			result, _, _ := procDefWindowProcW.Call(window, message, wParam, lParam)
			return result
		})
		type wndclassex struct {
			size, style         uint32
			wndProc             uintptr
			clsExtra, wndExtra  int32
			inst                uintptr
			icon, cursor, brush uintptr
			menuName, className *uint16
			iconSm              uintptr
		}
		wc := wndclassex{size: uint32(unsafe.Sizeof(wndclassex{})), wndProc: wndProc, inst: hInst, className: className}
		if atom, _, err := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wc))); atom == 0 {
			logf("session: RegisterClassExW failed: %v", err)
			return
		}
		hwnd, _, err := procCreateWindowExW.Call(0, uintptr(unsafe.Pointer(className)), uintptr(unsafe.Pointer(className)),
			0, 0, 0, 0, 0, 0, 0, hInst, 0)
		if hwnd == 0 {
			logf("session: CreateWindowExW failed: %v", err)
			return
		}
		var m msgStruct
		for {
			r, _, _ := procGetMessageW.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
			if r == 0 || int32(r) == -1 {
				return
			}
			procTranslateMessage.Call(uintptr(unsafe.Pointer(&m)))
			procDispatchMessageW.Call(uintptr(unsafe.Pointer(&m)))
		}
	}()
}
