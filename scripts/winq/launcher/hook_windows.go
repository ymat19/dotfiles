// 出典: https://github.com/omacom/try-omarchy-windows の app/winkey.go
// （コミット 5b1617edaef21942de08c1c64575cd7638f4808a）。MIT License、全文は同じディレクトリの LICENSE。
// 改変点: closeguard.go が × のクリックと Alt+F4 を捕まえるのに要る部分だけを抜き出した。
//   - qemuPid・guestUp の宣言は元のまま。
//   - hookCallback は Alt+F4 の分岐と、フックの連鎖（hookChaining・CallNextHookEx）だけを残した。
//     Win キー・Print Screen・Alt+Tab・Ctrl+Alt+End・Super+G の転送と Ctrl+Alt+G の
//     カーソル解放は持ち込まない（右 Win は Scancode Map で F13 にし、ゲストの xremap が
//     Super に戻している）。
//   - hookCallback の先頭で、右 Win（F13）+ Tab の仮想デスクトップ切り替え（vdesk_windows.go）を処理する。
//   - Alt+F4 の分岐で、確認ダイアログの親にするため前面ウィンドウを qemuHwnd に入れる 1 行を足した
//     （元では enforceDisplayWindows が毎秒入れていたが、それは持ち込んでいない）。
//   - runWinKeyHook はキーボードフックの付け直し（他のフックより前に居続けるため）と、
//     closeguard のマウスフックを元のまま残し、QEMU ウィンドウのイベントフック
//     （installQemuWindowHooks）の登録を外した。
//   - runWinKeyQmp（QMP へのキー転送）・runTitleEnforcer・runCursorReleaseGuard は持ち込まない。

//go:build windows

package main

import (
	"runtime"
	"sync/atomic"
	"syscall"
	"time"
	"unsafe"
)

var (
	qemuPid      atomic.Uint32 // current QEMU child, set by the supervisor
	guestUp      atomic.Bool   // supervisor handshake succeeded for this launch
	hookChaining bool          // hook-thread only
)

const (
	// rehookInterval paces the keyboard rehook in runWinKeyHook.
	rehookInterval = 800 * time.Millisecond
)

// winq:modified（このファイルの先頭の改変点を参照）
func hookCallback(nCode, wParam, lParam uintptr) uintptr {
	// While runWinKeyHook swaps hooks, both are briefly installed and this
	// one's CallNextHookEx can reach the other. Route each event once.
	if int32(nCode) >= 0 && !hookChaining {
		vk := *(*uint32)(unsafe.Pointer(lParam)) // KBDLLHOOKSTRUCT.vkCode
		// 改変: 右 Win（F13）+ Tab の仮想デスクトップ切り替え（見出しを参照）。
		if handleDesktopSwitchKey(vk, wParam, lParam) {
			return 1
		}
		if vk == vkF4 && wParam == wmSyskeydown { // Alt+F4 on the VM window
			if pid := qemuPid.Load(); pid != 0 && foregroundPid() == pid {
				// 改変: 確認ダイアログの親ウィンドウ（見出しを参照）。
				if hwnd, _, _ := procGetForegroundWindow.Call(); isQemuDisplayWindow(hwnd, pid) {
					qemuHwnd.Store(hwnd)
				}
				requestQuitConfirm()
				return 1 // swallow; the close guard takes it from here
			}
		}
	}
	chaining := hookChaining
	hookChaining = true
	r, _, _ := procCallNextHookEx.Call(0, nCode, wParam, lParam)
	hookChaining = chaining
	return r
}

// runWinKeyHook owns the hook and its message pump. LL hooks run newest-first
// and QEMU re-installs its own on every grab toggle, so the keyboard hook is
// re-installed every rehookInterval to stay at the front of the chain. The new
// hook goes in before the old one comes out, so no key event slips past both.
// winq:modified（このファイルの先頭の改変点を参照）
func runWinKeyHook() {
	runtime.LockOSThread()
	cb := syscall.NewCallback(hookCallback)
	mcb := syscall.NewCallback(mouseHookCallback)
	install := func() uintptr {
		h, _, _ := procSetWindowsHookExW.Call(whKeyboardLL, cb, 0, 0)
		return h
	}
	h := install()
	if h == 0 {
		logf("winkey: SetWindowsHookEx failed - Super forwarding disabled")
		return
	}
	// The close guard's mouse hook shares this thread's pump. Installed once;
	// only the keyboard hook needs the front-of-chain rehook dance (QEMU's
	// competing hook is keyboard-only).
	if mh, _, _ := procSetWindowsHookExW.Call(whMouseLL, mcb, 0, 0); mh == 0 {
		logf("closeguard: mouse hook failed - X clicks will be ignored (window-close=off)")
	}
	// 改変: installQemuWindowHooks()（QEMU ウィンドウのイベントフック）は持ち込まない。
	var m msgStruct
	rehooked := time.Now()
	for {
		// Every key event wakes this wait, so the rehook is paced by time.
		wait := max(rehookInterval-time.Since(rehooked), 0)
		procMsgWaitForMultipleObj.Call(0, 0, 0, uintptr(wait.Milliseconds()), qsAllinput)
		for {
			r, _, _ := procPeekMessageW.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0, pmRemove)
			if r == 0 {
				break
			}
		}
		if time.Since(rehooked) < rehookInterval {
			continue
		}
		rehooked = time.Now()
		if next := install(); next != 0 {
			procUnhookWindowsHookEx.Call(h)
			h = next
		}
		// On failure the old hook stays in, behind QEMU's at worst; retry
		// on the next interval.
	}
}
