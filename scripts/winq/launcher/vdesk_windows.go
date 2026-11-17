// 自分で書いたもの（Try Omarchy には無い）。
// 右 Win + Tab で、VM の仮想デスクトップと Windows の仮想デスクトップを行き来する。
//   - 右 Win は Windows の Scancode Map で F13 にしてある（Windows では F13 に何も割り当てが無く、
//     ゲストでは xremap が Super に戻す）。F13 自体はそのまま通す。
//   - F13 を押している間の Tab は、ゲストにも Windows にも渡さない（niri の Mod+Tab は起きない）。
//   - 前提は仮想デスクトップ 2 枚（左が Windows の作業用、右が VM）。VM のウィンドウが前面なら左へ、
//     そうでなければ右へ、Windows の仮想デスクトップ切り替え（Win+Ctrl+← / →）を SendInput で送る。
//     QEMU の SDL がキーボードを捕まえないこと（main.go の SDL_GRAB_KEYBOARD=0）が前提。
//     捕まえると、送ったキーを SDL のフックが取ってゲストに入れてしまう。
//   - Tab を押した回数だけ切り替える（右 Win を押したまま Tab を 2 回押せば、一度移って戻る）。
//     1 回ごとに前面のウィンドウが入れ替わるのを待ってから次を送るので、連打しても向きを取り違えない。
//     押しっぱなしの自動の繰り返しは数えない。
//   - QEMU はフォーカスを失ってもゲストのキーを離さない（QEMU の ui/sdl2.c）ので、切り替えの前に
//     F13 を離す入力を送り、ゲストの Super を離させる。

//go:build windows

package main

import (
	"sync/atomic"
	"time"
	"unsafe"
)

const (
	vkF13                = 0x7C
	scanF13              = 0x64
	vkLeft               = 0x25
	vkRight              = 0x27
	llkhfInjected        = 0x10
	inputKeyboard        = 1
	keyeventfExtendedkey = 0x1
	keyeventfKeyup       = 0x2
)

var (
	procSendInput   = user32.NewProc("SendInput")
	f13Held         atomic.Bool  // フックのスレッドだけが書く
	tabHeld         atomic.Bool  // 右 Win を押したまま押した Tab が、まだ離されていない
	desktopRequests atomic.Int32 // まだ済んでいない切り替えの回数
	desktopWorker   atomic.Bool  // 切り替えを順に送る goroutine が動いている
)

// handleDesktopSwitchKey はキーボードフックから呼ぶ。true を返したらそのキーを握りつぶす。
func handleDesktopSwitchKey(vk uint32, wParam, lParam uintptr) bool {
	flags := *(*uint32)(unsafe.Pointer(lParam + 8)) // KBDLLHOOKSTRUCT.flags
	if flags&llkhfInjected != 0 {
		return false // 自分で送ったキーはそのまま通す
	}
	down := wParam == wmKeydown || wParam == wmSyskeydown
	switch vk {
	case vkF13:
		f13Held.Store(down)
	case vkTab:
		if down && f13Held.Load() {
			if tabHeld.Swap(true) {
				return true // 押しっぱなしの自動の繰り返し
			}
			desktopRequests.Add(1)
			if desktopWorker.CompareAndSwap(false, true) {
				// フックの中で入力を送らない（フックの処理は短く保つ必要がある）。
				go runDesktopSwitches()
			}
			return true
		}
		if !down && tabHeld.Swap(false) {
			return true
		}
	}
	return false
}

// runDesktopSwitches は、たまった切り替えを 1 回ずつ、前の切り替えが終わってから送る。
func runDesktopSwitches() {
	for {
		for desktopRequests.Load() > 0 {
			desktopRequests.Add(-1)
			switchVirtualDesktop()
		}
		desktopWorker.Store(false)
		// 止める直前に増えた分を取りこぼさない。
		if desktopRequests.Load() == 0 || !desktopWorker.CompareAndSwap(false, true) {
			return
		}
	}
}

type keyInput struct {
	inputType uint32
	_         uint32 // INPUT の union の 8 バイト境界
	vk        uint16
	scan      uint16
	flags     uint32
	time      uint32
	_         uint32
	extraInfo uintptr
	_         [8]byte // INPUT は MOUSEINPUT の大きさ（64 ビットで 40 バイト）
}

func switchVirtualDesktop() {
	pid := qemuPid.Load()
	onVM := pid != 0 && foregroundPid() == pid
	arrow := uint16(vkRight)
	if onVM {
		arrow = vkLeft
	}
	key := func(vk, scan uint16, up bool) keyInput {
		f := uint32(0)
		if vk == vkLwin || vk == vkLeft || vk == vkRight {
			f |= keyeventfExtendedkey
		}
		if up {
			f |= keyeventfKeyup
		}
		return keyInput{inputType: inputKeyboard, vk: vk, scan: scan, flags: f}
	}
	in := []keyInput{
		key(vkF13, scanF13, true),
		key(vkLwin, 0, false), key(vkLControl, 0, false), key(arrow, 0, false),
		key(arrow, 0, true), key(vkLControl, 0, true), key(vkLwin, 0, true),
	}
	n, _, err := procSendInput.Call(uintptr(len(in)), uintptr(unsafe.Pointer(&in[0])), unsafe.Sizeof(in[0]))
	if int(n) != len(in) {
		logf("vdesk: SendInput sent %d/%d: %v", n, len(in), err)
		return
	}
	// 前面のウィンドウが入れ替わる（切り替えが終わる）まで待つ。入れ替わらなくても 1 秒で打ち切る。
	for deadline := time.Now().Add(time.Second); time.Now().Before(deadline); {
		if (pid != 0 && foregroundPid() == pid) != onVM {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	logf("vdesk: the foreground window did not change within 1s")
}
