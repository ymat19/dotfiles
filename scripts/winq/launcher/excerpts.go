// 出典: https://github.com/omacom/try-omarchy-windows の app/ 以下の複数のファイル
// （コミット 5b1617edaef21942de08c1c64575cd7638f4808a）。MIT License、全文は同じディレクトリの LICENSE。
// 持ち込んだファイルが参照する関数・型・定数を、元のファイルから抜き出して無改変で集めたもの。
// 元のファイルの残りは、このランチャーが持ち込まない機能（ゲストのダウンロード、バックアップ、
// セーブ、移動、音声デバイスの選択など）のためのものなので持ち込まない。
// 各ブロックの前に元のファイル名を書いている。

package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ---- app/disk_space.go（抜粋） ----

const (
	diskSpaceReserve int64 = 1 << 30
)

var errInsufficientDiskSpace = errors.New("not enough free disk space")

var (
	diskFreeBytes = platformDiskFreeBytes
)

func requireDiskSpace(path string, required int64) error {
	if required <= 0 {
		return nil
	}
	available, err := diskFreeBytes(path)
	if err != nil {
		return fmt.Errorf("checking free disk space: %w", err)
	}
	if available < required {
		return fmt.Errorf("%w in %s: need %s available, have %s",
			errInsufficientDiskSpace, filepath.Clean(path), formatGiB(required), formatGiB(available))
	}
	return nil
}

func formatGiB(bytes int64) string {
	return fmt.Sprintf("%.1f GiB", float64(bytes)/float64(int64(1)<<30))
}

// ---- app/host_disk_warnings.go（抜粋） ----

type diskVolumeSpace struct{ available, total int64 }

func boundedDiskBytes(bytes uint64) int64 {
	if bytes > uint64(1<<63-1) {
		return 1<<63 - 1
	}
	return int64(bytes)
}

// ---- app/manifest.go（抜粋） ----

func validSHA256(value string) bool {
	if len(value) != sha256.Size*2 {
		return false
	}
	_, err := hex.DecodeString(value)
	return err == nil
}

// ---- app/backup.go（抜粋） ----

const backupMaxFiles = 10000
const backupMaxBytes int64 = 2 << 40

// Progress is optional so archive tests and noninteractive callers never create UI.
type backupProgress func(current, total int64, name string)

// ---- app/saved_session_runtime.go（抜粋） ----

type savedMemoryFile struct {
	Bytes  int64  `json:"bytes"`
	SHA256 string `json:"sha256"`
}

func hashSavedMemory(ctx context.Context, f *os.File) (savedMemoryFile, error) {
	var result savedMemoryFile
	info, err := f.Stat()
	if err != nil {
		return result, err
	}
	if !info.Mode().IsRegular() || info.Size() <= 0 || info.Size() > 2<<40 {
		return result, fmt.Errorf("invalid saved memory file")
	}
	h := sha256.New()
	buffer := make([]byte, 1<<20)
	for {
		if err := ctx.Err(); err != nil {
			return result, err
		}
		n, err := f.Read(buffer)
		if n > 0 {
			h.Write(buffer[:n])
			result.Bytes += int64(n)
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return result, err
		}
	}
	if result.Bytes != info.Size() {
		return result, fmt.Errorf("saved memory changed during verification")
	}
	result.SHA256 = hex.EncodeToString(h.Sum(nil))
	return result, nil
}

// ---- app/move.go（抜粋） ----

// Reject links in every existing path component, including Windows junctions.
// Only the path itself gets the additional-stream check: ancestor directories
// are outside this installation and may legitimately carry unrelated streams
// (e.g. clipboard/tooling data on the user's profile folder).
func validateMovePath(path string) error {
	first := true
	for current := filepath.Clean(path); ; current = filepath.Dir(current) {
		info, err := os.Lstat(current)
		if err != nil && !os.IsNotExist(err) {
			return err
		}
		if err == nil {
			if first {
				if err := rejectMoveLink(current, info); err != nil {
					return err
				}
			} else if err := rejectAncestorLink(current, info); err != nil {
				return err
			}
		}
		first = false
		if filepath.Dir(current) == current {
			return nil
		}
	}
}

// ---- app/audio_endpoints.go（抜粋） ----

type audioEndpointInfo struct {
	ID         string
	Name       string
	SampleRate int
}

type mmDeviceList struct {
	Output, Input                       []audioEndpointInfo
	DefaultOutputRate, DefaultInputRate int
}

// ---- app/audio_sample_rates.go（抜粋） ----

func validAudioSampleRate(rate int) bool {
	return rate >= 1000 && rate < 1000000
}

// PKEY_AudioEngine_DeviceFormat contains a WAVEFORMATEX or WAVEFORMATEXTENSIBLE.
func audioSampleRateFromWaveFormat(format []byte) int {
	if len(format) < 18 {
		return 0
	}
	rate := int(binary.LittleEndian.Uint32(format[4:8]))
	if !validAudioSampleRate(rate) {
		return 0
	}
	return rate
}

// ---- app/audio_preferences.go（抜粋） ----

func runtimeHasPatch(qemu, patch string) bool {
	path := filepath.Join(filepath.Dir(filepath.Dir(qemu)), "provenance", "sources.lock.json")
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	var lock struct {
		QEMU struct {
			Patches []struct {
				File string `json:"file"`
			} `json:"patches"`
		} `json:"qemu"`
	}
	if json.NewDecoder(io.LimitReader(f, 65536)).Decode(&lock) != nil {
		return false
	}
	for _, p := range lock.QEMU.Patches {
		if p.File == patch {
			return true
		}
	}
	return false
}

// ---- app/qemu.go（抜粋） ----

// Keep the original failure in shell.log before a fallback truncates stderr.
// Limit the tail so a noisy failed runtime cannot flood the launcher log.
func qemuStartupFailureTail(vmDir string) string {
	f, err := os.Open(filepath.Join(vmDir, "qemu-stderr.log"))
	if err != nil {
		return ""
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() {
		return ""
	}
	const limit = 16 * 1024
	start := max(int64(0), info.Size()-limit)
	data, err := io.ReadAll(io.NewSectionReader(f, start, limit))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// QEMU's structured option parser uses commas as separators and represents a
// literal comma as two commas. Paths are already separate argv values, but a
// folder such as C:\Work,Notes still needs this option-level escaping.
func qemuOptionValue(value string) string {
	return strings.ReplaceAll(value, ",", ",,")
}

// audioUnavailable distinguishes a missing audio device from unrelated
// startup failures. Retrying every failure without audio used to consume a
// fallback attempt even when the real problem was memory or graphics.
func audioUnavailable(cfg *config) bool {
	data, err := os.ReadFile(filepath.Join(cfg.vmDir, "qemu-stderr.log"))
	if err != nil {
		return false
	}
	message := bytes.ToLower(data)
	return bytes.Contains(message, []byte("dsound:")) ||
		bytes.Contains(message, []byte("directsound")) ||
		bytes.Contains(message, []byte("dsound audio driver")) ||
		bytes.Contains(message, []byte("sdl failed to initialize audio subsystem")) ||
		bytes.Contains(message, []byte("sdl_openaudiodevice for playback failed")) ||
		bytes.Contains(message, []byte("sdl_openaudiodevice for recording failed")) ||
		bytes.Contains(message, []byte("sdl audio driver"))
}

func sdlDisplay(gpu, hostCursor bool) string {
	gl := "off"
	if gpu {
		gl = "on"
	}
	cursor := "off"
	if hostCursor {
		cursor = "on"
	}
	return "sdl,gl=" + gl + ",show-cursor=" + cursor + ",window-close=off"
}

// ---- app/main.go（抜粋） ----

// waitExit reaps QEMU: stock WHPX wedges instead of exiting after a guest
// shutdown, so after a grace period the husk is killed. Returns true once the
// process is gone.
func waitExit(exited <-chan error, grace time.Duration, cfg *config) bool {
	select {
	case <-exited:
		return true
	case <-time.After(grace):
		logf("QEMU wedged after guest shutdown (stock WHPX trap) - cleaning up")
		if pid := qemuPid.Load(); pid != 0 {
			if p, err := os.FindProcess(int(pid)); err == nil {
				p.Kill()
			}
		}
		<-exited
		return true
	}
}

// ---- app/gpu_recovery.go（抜粋） ----

const qmpHangMisses = 19

type qmpSilence struct{ misses int }

func (s *qmpSilence) answered()   { s.misses = 0 }
func (s *qmpSilence) probe() bool { s.misses++; return s.misses >= qmpHangMisses }
