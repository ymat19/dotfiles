// 出典: https://github.com/omacom/try-omarchy-windows の app/ 以下の複数のファイル
// （コミット 5b1617edaef21942de08c1c64575cd7638f4808a）。MIT License、全文は同じディレクトリの LICENSE。
// excerpts.go の Windows 版。持ち込んだファイルが参照する関数・定数を、元のファイルから
// 抜き出して無改変で集めたもの。各ブロックの前に元のファイル名を書いている。
// ただし rejectMoveStreams だけは改変している（Zone.Identifier を許す。関数内のコメントを参照）。

//go:build windows

package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"unsafe"
)

// ---- app/ui.go（抜粋: 使う宣言だけ） ----

var (
	procCreateWindowExW  = user32.NewProc("CreateWindowExW")
	procDefWindowProcW   = user32.NewProc("DefWindowProcW")
	procRegisterClassExW = user32.NewProc("RegisterClassExW")
	procGetMessageW      = user32.NewProc("GetMessageW")
	procTranslateMessage = user32.NewProc("TranslateMessage")
	procDispatchMessageW = user32.NewProc("DispatchMessageW")
	procSendMessageW     = user32.NewProc("SendMessageW")
	procGetModuleHandleW = kernel32.NewProc("GetModuleHandleW")
)

const (
	wmNchittest = 0x0084
)

// ---- app/setup.go（抜粋） ----

const (
	mbIconInfo     = 0x40
	mbIconQuestion = 0x20
	mbYesNo        = 0x04
	idYes          = 6
	idNo           = 7
)

func msgBox(text string, flags uintptr) int {
	t, _ := syscall.UTF16PtrFromString(text)
	c, _ := syscall.UTF16PtrFromString(appTitle)
	r, _, _ := procMessageBoxW.Call(0, uintptr(unsafe.Pointer(t)), uintptr(unsafe.Pointer(c)), flags|mbFront)
	return int(r)
}

// ---- app/disk_space_windows.go（抜粋） ----

var (
	procGetDiskFreeSpaceExW = syscall.NewLazyDLL("kernel32.dll").NewProc("GetDiskFreeSpaceExW")
)

func existingDiskPath(path string) (string, error) {
	path = filepath.Clean(path)
	for {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		} else if !os.IsNotExist(err) {
			return "", err
		}
		parent := filepath.Dir(path)
		if parent == path {
			return "", fmt.Errorf("no existing parent for %s", path)
		}
		path = parent
	}
}

func platformDiskFreeBytes(path string) (int64, error) {
	space, err := platformDiskVolumeSpace(path)
	return space.available, err
}

func platformDiskVolumeSpace(path string) (diskVolumeSpace, error) {
	existing, err := existingDiskPath(path)
	if err != nil {
		return diskVolumeSpace{}, err
	}
	ptr, err := syscall.UTF16PtrFromString(existing)
	if err != nil {
		return diskVolumeSpace{}, err
	}
	var available, total uint64
	r1, _, callErr := procGetDiskFreeSpaceExW.Call(uintptr(unsafe.Pointer(ptr)), uintptr(unsafe.Pointer(&available)), uintptr(unsafe.Pointer(&total)), 0)
	if r1 == 0 {
		return diskVolumeSpace{}, callErr
	}
	return diskVolumeSpace{available: boundedDiskBytes(available), total: boundedDiskBytes(total)}, nil
}

// ---- app/launcher_windows.go（抜粋） ----

var procMoveFileExW = kernel32.NewProc("MoveFileExW")

const (
	moveFileWriteThrough = 0x8
)

// ---- app/publish_new_windows.go ----

func publishNewDirectory(from, to string) error {
	source, err := syscall.UTF16PtrFromString(from)
	if err != nil {
		return err
	}
	target, err := syscall.UTF16PtrFromString(to)
	if err != nil {
		return err
	}
	result, _, err := procMoveFileExW.Call(uintptr(unsafe.Pointer(source)), uintptr(unsafe.Pointer(target)), moveFileWriteThrough)
	if result == 0 {
		return err
	}
	return nil
}

// ---- app/saved_memory_windows.go ----

// QEMU can read the stream while this handle denies writers and replacement.
func openSavedMemory(path string) (*os.File, error) {
	name, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}
	handle, err := syscall.CreateFile(name, syscall.GENERIC_READ, syscall.FILE_SHARE_READ, nil, syscall.OPEN_EXISTING, syscall.FILE_ATTRIBUTE_NORMAL, 0)
	if err != nil {
		return nil, err
	}
	return os.NewFile(uintptr(handle), path), nil
}

// ---- app/shared_folder_windows.go（抜粋） ----

const (
	fileAttributeReparsePoint = 0x400
)

// ---- app/move_windows.go（抜粋） ----

func rejectAncestorLink(path string, info os.FileInfo) error {
	ptr, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return err
	}
	attributes, err := syscall.GetFileAttributes(ptr)
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink != 0 || attributes&fileAttributeReparsePoint != 0 {
		return fmt.Errorf("linked paths cannot be moved: %s", path)
	}
	return nil
}

func rejectMoveLink(path string, info os.FileInfo) error {
	if err := rejectAncestorLink(path, info); err != nil {
		return err
	}
	return rejectMoveStreams(path)
}

func moveStreamsAbsent(err error) bool {
	return errors.Is(err, syscall.Errno(38)) || // ERROR_HANDLE_EOF
		errors.Is(err, syscall.Errno(87)) || // ERROR_INVALID_PARAMETER
		errors.Is(err, syscall.Errno(1)) // ERROR_INVALID_FUNCTION
}

// winq:modified（Zone.Identifier を許す。関数内のコメントを参照）
func rejectMoveStreams(path string) error {
	ptr, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return err
	}
	var data struct {
		Size int64
		Name [296]uint16
	}
	first := kernel32.NewProc("FindFirstStreamW")
	next := kernel32.NewProc("FindNextStreamW")
	h, _, callErr := first.Call(uintptr(unsafe.Pointer(ptr)), 0, uintptr(unsafe.Pointer(&data)), 0)
	if h == ^uintptr(0) {
		if moveStreamsAbsent(callErr) {
			return nil
		}
		return fmt.Errorf("checking file streams for %s: %v", path, callErr)
	}
	defer syscall.FindClose(syscall.Handle(h))
	for {
		// 改変: Zone.Identifier（ダウンロードしたファイルに Windows が付ける「インターネットから
		// 取得した」印）だけは拒否しない。元のままだと、ダウンロードしたファイルをクリップボードで
		// VM に送れない。転送されるのは本体（::$DATA）だけで、この印は VM には渡らない。
		if name := syscall.UTF16ToString(data.Name[:]); name != "::$DATA" && !strings.EqualFold(name, ":Zone.Identifier:$DATA") {
			return uiError(uiTextWith("error.move.data_stream", map[string]string{"path": path}), nil)
		}
		r, _, e := next.Call(h, uintptr(unsafe.Pointer(&data)))
		if r == 0 {
			if e == syscall.Errno(38) {
				return nil
			}
			return fmt.Errorf("checking file streams: %v", e)
		}
	}
}
