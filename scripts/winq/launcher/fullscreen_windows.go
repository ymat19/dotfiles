// 自分で書いたもの。上流の title enforcer（app/winkey.go の runTitleEnforcer から app/winapi.go の
// enforceDisplayWindows・enumTitleProc）が QEMU の表示ウィンドウごとに行う処理のうち、全画面に関わる
// 2 つだけを同じ順で行う（syncFullscreenMark のあと growFullscreenWindow。どちらもビルド時に上流から抜き出す。excerpts.txt）。
//   - growFullscreenWindow: モニターをちょうど覆う全画面のウィンドウを 1 行大きくする。グラフィックドライバが
//     排他的な全画面として扱い、ポインタなどが上に描かれるたびに黒くちらつくのを防ぐ（上流の #422）。
//   - syncFullscreenMark: 1 行大きくすると Windows が全画面と見なさずタスクバーを上に出すので、
//     タスクバーに全画面と伝える。
// 上流はウィンドウのイベントでもすぐに見直すが、そのフックは持ち込んでいないので、250 ms ごとに見る
// （上流は起動中 250 ms、それ以外は 1 秒ごと）。全画面に切り替えた直後は、最大でこの間だけちらつきうる。

//go:build windows

package main

import (
	"syscall"
	"time"
)

var fullscreenKeeperPid uint32 // runFullscreenKeeper のスレッドだけが使う

var fullscreenKeeperCallback = syscall.NewCallback(func(hwnd, _ uintptr) uintptr {
	if visible, _, _ := procIsWindowVisible.Call(hwnd); visible != 0 && isQemuDisplayWindow(hwnd, fullscreenKeeperPid) {
		syncFullscreenMark(hwnd)
		growFullscreenWindow(hwnd)
	}
	return 1
})

func runFullscreenKeeper() {
	for {
		if pid := qemuPid.Load(); pid != 0 {
			fullscreenKeeperPid = pid
			procEnumWindows.Call(fullscreenKeeperCallback, 0)
		}
		time.Sleep(250 * time.Millisecond)
	}
}
