// 出典: https://github.com/omacom/try-omarchy-windows の app/winapi.go
// （コミット 5b1617edaef21942de08c1c64575cd7638f4808a）。MIT License、全文は同じディレクトリの LICENSE。
// 改変点: 必要な部分だけを抜き出した。残した部分（DLL・関数の宣言、定数、msgStruct、errorBox、
// foregroundPid、isQemuDisplayWindow、クリップボードの読み書き一式）は元のまま。
// 外したもの: availMemMiB、setSparse、sparseCopy、screenSize、releaseQemuCursor、
// 表示ウィンドウの題名・位置・全画面を整える enforceDisplayWindows 一式（enumTitle*、
// displayWindowState）、punchHole。どれもディスクの作成・ウィンドウ配置・起動画面など
// このランチャーが持ち込まない機能のためのもの。
// 外した影響: 元では enforceDisplayWindows が qemuHwnd（確認ダイアログの親ウィンドウ）を
// 毎秒更新していた。ここでは × のクリック時（closeguard.go）と Alt+F4 の押下時（hook_windows.go）に設定する。

//go:build windows

package main

import (
	"runtime"
	"syscall"
	"time"
	"unsafe"
)

var (
	user32   = syscall.NewLazyDLL("user32.dll")
	kernel32 = syscall.NewLazyDLL("kernel32.dll")
	advapi32 = syscall.NewLazyDLL("advapi32.dll")

	procMessageBoxW              = user32.NewProc("MessageBoxW")
	procSetWindowsHookExW        = user32.NewProc("SetWindowsHookExW")
	procUnhookWindowsHookEx      = user32.NewProc("UnhookWindowsHookEx")
	procCallNextHookEx           = user32.NewProc("CallNextHookEx")
	procGetForegroundWindow      = user32.NewProc("GetForegroundWindow")
	procGetWindowThreadProcessId = user32.NewProc("GetWindowThreadProcessId")
	procGetAsyncKeyState         = user32.NewProc("GetAsyncKeyState")
	procClipCursor               = user32.NewProc("ClipCursor")
	procMsgWaitForMultipleObj    = user32.NewProc("MsgWaitForMultipleObjects")
	procPeekMessageW             = user32.NewProc("PeekMessageW")
	procEnumWindows              = user32.NewProc("EnumWindows")
	procIsWindowVisible          = user32.NewProc("IsWindowVisible")
	procGetWindowTextW           = user32.NewProc("GetWindowTextW")
	procSetWindowTextW           = user32.NewProc("SetWindowTextW")
	procOpenClipboard            = user32.NewProc("OpenClipboard")
	procCloseClipboard           = user32.NewProc("CloseClipboard")
	procEmptyClipboard           = user32.NewProc("EmptyClipboard")
	procGetClipboardData         = user32.NewProc("GetClipboardData")
	procSetClipboardData         = user32.NewProc("SetClipboardData")
	procGetClipboardSequenceNum  = user32.NewProc("GetClipboardSequenceNumber")
	procRegisterClipboardFormatW = user32.NewProc("RegisterClipboardFormatW")
	procIsClipboardFormatAvail   = user32.NewProc("IsClipboardFormatAvailable")
	procSystemParametersInfoW    = user32.NewProc("SystemParametersInfoW")
	procGlobalAlloc              = kernel32.NewProc("GlobalAlloc")
	procGlobalSize               = kernel32.NewProc("GlobalSize")
	procGlobalLock               = kernel32.NewProc("GlobalLock")
	procGlobalUnlock             = kernel32.NewProc("GlobalUnlock")
	procGlobalFree               = kernel32.NewProc("GlobalFree")
	procDeviceIoControl          = kernel32.NewProc("DeviceIoControl")
)

const (
	mbIconError      = 0x10
	whKeyboardLL     = 13
	wmKeydown        = 0x100
	wmKeyup          = 0x101
	wmSyskeydown     = 0x104
	wmSyskeyup       = 0x105
	vkTab            = 0x09
	vkControl        = 0x11
	vkMenu           = 0x12
	vkEnd            = 0x23
	vkG              = 0x47
	vkLControl       = 0xA2
	vkLMenu          = 0xA4
	vkLwin           = 0x5B
	vkRwin           = 0x5C
	vkSnapshot       = 0x2C
	qsAllinput       = 0x04FF
	pmRemove         = 1
	cfUnicodetext    = 13
	cfDib            = 8
	cfDibV5          = 17
	gmemMoveable     = 2
	fsctlSetSparse   = 0x900C4
	fsctlSetZeroData = 0x980C8
	maxTitle         = 256
)

type msgStruct struct {
	hwnd    uintptr
	message uint32
	wParam  uintptr
	lParam  uintptr
	time    uint32
	ptX     int32
	ptY     int32
}

// mbFront forces a dialog above everything and steals focus - errors from a
// background phase were invisible behind other windows, which reads as "the
// app silently died" (it happened, pre-announcement).
const mbFront = 0x50000 // MB_TOPMOST | MB_SETFOREGROUND

func errorBox(text string) {
	t, _ := syscall.UTF16PtrFromString(text)
	c, _ := syscall.UTF16PtrFromString(appTitle)
	procMessageBoxW.Call(0, uintptr(unsafe.Pointer(t)), uintptr(unsafe.Pointer(c)), mbIconError|mbFront)
}

// foregroundPid is the process of the foreground window. A guest window that
// is still invisible while Omarchy boots does not count as the VM having focus.
func foregroundPid() uint32 {
	if curtainUp.Load() {
		return 0
	}
	hwnd, _, _ := procGetForegroundWindow.Call()
	if hwnd == 0 {
		return 0
	}
	var pid uint32
	procGetWindowThreadProcessId.Call(hwnd, uintptr(unsafe.Pointer(&pid)))
	return pid
}

var procGetClassNameW = user32.NewProc("GetClassNameW")

func isQemuDisplayWindow(hwnd uintptr, pid uint32) bool {
	var owner uint32
	procGetWindowThreadProcessId.Call(hwnd, uintptr(unsafe.Pointer(&owner)))
	if pid == 0 || owner != pid {
		return false
	}
	var class [64]uint16
	procGetClassNameW.Call(hwnd, uintptr(unsafe.Pointer(&class[0])), uintptr(len(class)))
	return syscall.UTF16ToString(class[:]) == "SDL_app"
}

func clipboardGetText() (string, bool) {
	text, status := clipboardReadText()
	return text, status == clipboardReady
}

func clipboardReadText() (string, clipboardReadStatus) {
	if r, _, _ := procIsClipboardFormatAvail.Call(cfUnicodetext); r == 0 {
		return "", clipboardUnsupported
	}
	if !openClipboard() {
		return "", clipboardRetry
	}
	defer procCloseClipboard.Call()
	h, _, _ := procGetClipboardData.Call(cfUnicodetext)
	if h == 0 {
		return "", clipboardRetry
	}
	size, _, _ := procGlobalSize.Call(h)
	if size < 2 || size > uintptr((maxClipboardTextBytes+1)*2) {
		return "", clipboardRejected
	}
	p, _, _ := procGlobalLock.Call(h)
	if p == 0 {
		return "", clipboardRetry
	}
	defer procGlobalUnlock.Call(h)
	maxChars := int(size / 2)
	chars := make([]uint16, 0, maxChars)
	for i := 0; i < maxChars; i++ {
		c := *(*uint16)(unsafe.Pointer(p + uintptr(i)*2))
		if c == 0 {
			text := syscall.UTF16ToString(chars)
			if !clipboardTextAllowed(text) {
				return "", clipboardRejected
			}
			return text, clipboardReady
		}
		chars = append(chars, c)
	}
	// CF_UNICODETEXT is required to be NUL-terminated. Refuse a malformed
	// clipboard handle instead of reading beyond its allocation.
	return "", clipboardRejected
}

func clipboardSetText(s string) bool {
	u, err := syscall.UTF16FromString(s)
	if err != nil {
		return false
	}
	size := uintptr(len(u) * 2)
	h, _, _ := procGlobalAlloc.Call(gmemMoveable, size)
	if h == 0 {
		return false
	}
	p, _, _ := procGlobalLock.Call(h)
	if p == 0 {
		procGlobalFree.Call(h)
		return false
	}
	dst := unsafe.Slice((*uint16)(unsafe.Pointer(p)), len(u))
	copy(dst, u)
	procGlobalUnlock.Call(h)
	if !openClipboard() {
		procGlobalFree.Call(h)
		return false
	}
	defer procCloseClipboard.Call()
	procEmptyClipboard.Call()
	if r, _, _ := procSetClipboardData.Call(cfUnicodetext, h); r == 0 {
		procGlobalFree.Call(h)
		return false
	}
	return true // the system owns the handle after SetClipboardData succeeds
}

func openClipboard() bool {
	for attempt := 0; attempt < 20; attempt++ {
		if r, _, _ := procOpenClipboard.Call(0); r != 0 {
			return true
		}
		time.Sleep(25 * time.Millisecond)
	}
	return false
}

// pngClipboardFormat is the registered "PNG" format browsers and image
// editors use beside CF_DIB. Registering an existing name returns its id.
var pngClipboardFormat = func() uintptr {
	name, _ := syscall.UTF16PtrFromString("PNG")
	id, _, _ := procRegisterClipboardFormatW.Call(uintptr(unsafe.Pointer(name)))
	return id
}()

func clipboardSequence() uint32 {
	seq, _, _ := procGetClipboardSequenceNum.Call()
	return uint32(seq)
}

// clipboardGetItem reads the Windows clipboard as text when text is offered,
// otherwise as a PNG image from the registered PNG format or a DIB.
func clipboardGetItem() (clipItem, bool) {
	item, status := clipboardReadItem()
	return item, status == clipboardReady
}
func clipboardReadItem() (clipItem, clipboardReadStatus) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	if r, _, _ := procIsClipboardFormatAvail.Call(cfHDrop); r != 0 {
		item, status := clipboardReadFiles()
		if status != clipboardUnsupported {
			return item, status
		}
	}
	return clipboardReadNonFileItem()
}

func clipboardReadNonFileItem() (clipItem, clipboardReadStatus) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	if text, status := clipboardReadText(); status != clipboardUnsupported {
		return textItem(text), status
	}
	hasPNG, _, _ := procIsClipboardFormatAvail.Call(pngClipboardFormat)
	hasDIB, _, _ := procIsClipboardFormatAvail.Call(cfDib)
	hasDIBV5, _, _ := procIsClipboardFormatAvail.Call(cfDibV5)
	if hasPNG == 0 && hasDIB == 0 && hasDIBV5 == 0 {
		return clipItem{}, clipboardUnsupported
	}
	if !openClipboard() {
		return clipItem{}, clipboardRetry
	}
	defer procCloseClipboard.Call()
	if hasPNG != 0 {
		data, status := clipboardGlobalBytesStatus(pngClipboardFormat, maxClipboardImageBytes)
		if status == clipboardRetry {
			return clipItem{}, status
		}
		if status == clipboardReady {
			item := pngItem(data)
			if item.allowed() {
				return item, clipboardReady
			}
		}
	}
	format := uintptr(cfDib)
	if hasDIBV5 != 0 {
		format = cfDibV5
	} else if hasDIB == 0 {
		return clipItem{}, clipboardRejected
	}
	dib, status := clipboardGlobalBytesStatus(format, maxClipboardDIBBytes)
	if status != clipboardReady {
		return clipItem{}, status
	}
	data, err := dibToPNG(dib)
	if err != nil {
		return clipItem{}, clipboardRejected
	}
	item := pngItem(data)
	if !item.allowed() {
		return clipItem{}, clipboardRejected
	}
	return item, clipboardReady
}

// clipboardGlobalBytes copies a clipboard handle's memory; the clipboard
// must already be open.
func clipboardGlobalBytes(format uintptr, limit int) ([]byte, bool) {
	data, status := clipboardGlobalBytesStatus(format, limit)
	return data, status == clipboardReady
}
func clipboardGlobalBytesStatus(format uintptr, limit int) ([]byte, clipboardReadStatus) {
	h, _, _ := procGetClipboardData.Call(format)
	if h == 0 {
		return nil, clipboardRetry
	}
	size, _, _ := procGlobalSize.Call(h)
	if size == 0 {
		return nil, clipboardUnsupported
	}
	if size > uintptr(limit) {
		return nil, clipboardRejected
	}
	p, _, _ := procGlobalLock.Call(h)
	if p == 0 {
		return nil, clipboardRetry
	}
	defer procGlobalUnlock.Call(h)
	return append([]byte(nil), unsafe.Slice((*byte)(unsafe.Pointer(p)), int(size))...), clipboardReady
}

func clipboardSetItem(item clipItem) bool {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	if item.Kind == clipFiles {
		return clipboardSetFiles(item)
	}
	if item.Kind == clipText {
		return clipboardSetText(string(item.Data))
	}
	dib, err := pngToDIB(item.Data)
	if err != nil {
		return false
	}
	hDib := globalCopy(dib)
	hPNG := globalCopy(item.Data)
	if hDib == 0 || hPNG == 0 {
		procGlobalFree.Call(hDib)
		procGlobalFree.Call(hPNG)
		return false
	}
	if !openClipboard() {
		procGlobalFree.Call(hDib)
		procGlobalFree.Call(hPNG)
		return false
	}
	defer procCloseClipboard.Call()
	procEmptyClipboard.Call()
	if r, _, _ := procSetClipboardData.Call(cfDib, hDib); r == 0 {
		procGlobalFree.Call(hDib)
		procGlobalFree.Call(hPNG)
		return false
	}
	if r, _, _ := procSetClipboardData.Call(pngClipboardFormat, hPNG); r == 0 {
		procGlobalFree.Call(hPNG)
	}
	return true
}

func globalCopy(data []byte) uintptr {
	h, _, _ := procGlobalAlloc.Call(gmemMoveable, uintptr(len(data)))
	if h == 0 {
		return 0
	}
	p, _, _ := procGlobalLock.Call(h)
	if p == 0 {
		procGlobalFree.Call(h)
		return 0
	}
	copy(unsafe.Slice((*byte)(unsafe.Pointer(p)), len(data)), data)
	procGlobalUnlock.Call(h)
	return h
}
