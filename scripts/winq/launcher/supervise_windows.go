// 出典: https://github.com/omacom/try-omarchy-windows の app/main.go の supervise / watch /
// runLifecycleListener（コミット 5b1617edaef21942de08c1c64575cd7638f4808a）。MIT License、全文は上流の LICENSE。
// 上流からの改変が大きくパッチに向かないので、ここで持つ。元のままの宣言（pendingReboot・guestReady）は
// ビルド時に上流から抜き出す（excerpts.txt）。
//
// 改変点（流れと判定は元のまま。持ち込まない機能に関わる枝を外した）:
//   supervise
//     - 残したもの: 起動ごとの QMP 制御ソケットの用意、qemu-stderr.log の起動ごとの切り詰め、
//       guestLaunchInProgress / windowsSessionEnding / guestExitedCleanly / guest-exit.json の扱い、
//       起動直後に QMP に触らない待ち（10 秒、以後 3 秒おき、60 秒で打ち切り）、
//       QMP が答えなければ QEMU を止めてやり直す、起動直後に音声デバイスが無くて落ちたら
//       sdl → dsound → none で起動し直す。
//     - 外したもの: ランタイムの事前読み込み、更新・ロールバック、起動画面、音声デバイスの選択と
//       サンプルレート、ピンチ、外部キーボードフック、GPU 診断、ポート転送の一時停止、
//       ネストした仮想化の再試行（このランタイムはパッチ 0001 で拒否されても続行する）、
//       メモリ不足時にメモリを半分にする再試行、GPU から CPU 描画への切り替え、USB の再接続、
//       セットアップの取り消し。起動回数の上限は元の 12 から、残した再試行（音声の 2 回）に合わせて 4 にした。
//   watch
//     - 残したもの: QMP のイベントを読み続けて SHUTDOWN の reason で再起動か電源オフかを決める、
//       5 秒ごとの query-status、ループ後に保留中の SHUTDOWN を拾う、15 秒待っても終わらない QEMU を止める、
//       ゲストが lifecycle ポートで知らせた再起動（pendingReboot）で判定を補う。
//     - 外したもの: 起動完了（ready）後の更新の確定、描画の記録、ファイルのドロップ、ディスク満杯の通知、
//       セットアップの取り消し、表示が固まったときの復旧ダイアログ（GPU 回復）。
//       元は起動完了後に QMP が切れたり答えなくなったりすると復旧ダイアログを出して VM を残す。
//       ここではダイアログを出さずにログに書き、同じく VM は止めない。起動完了の通知（ready）は
//       ゲストから送っていないので、起動完了前に QMP が切れたら QEMU を止める元の枝は使わない。
//   runLifecycleListener
//     - reboot / shutdown / ready だけを扱う。open-url（リンクを Windows で開く）と reclaim
//       （ディスクの空き回収）は持ち込まない。ポートが使用中なら既存のランチャーを前面に出す代わりに終了する。

//go:build windows

package main

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// supervise runs one guest lifetime: launch with the wedge watchdog, watch it
// until the guest goes down, reap a wedged QEMU. Returns true when the guest
// rebooted (with -no-reboot a guest reset exits QEMU; relaunching IS the
// reboot). The two hard-won subtleties from launch-omarchy.ps1 are preserved:
// liveness is probed (a QEMU wedged at guest poweroff cannot deliver its
// SHUTDOWN event), and a read stays permanently pending so a fast exit after
// guest-reset cannot discard the event (see docs/FINDINGS.md).
func supervise(cfg *config) bool {
	var proc *exec.Cmd
	var qmp *qmpConn
	const maxLaunchAttempts = 4
	for attempt := 1; attempt <= maxLaunchAttempts; attempt++ {
		if windowsSessionEnding.Load() {
			return false
		}
		logf("booting (attempt %d, audio %s)", attempt, cfg.audio)
		pendingReboot.Store(false)
		guestReady.Store(false)
		controlDir, err := prepareQMPControl()
		if err != nil {
			fatal(uiTextWith("fatal.vm_controls", map[string]string{"error": err.Error()}))
		}
		cfg.qmpDir = controlDir
		args := buildQemuArgs(cfg)
		logf("qemu: %s %q", cfg.qemu, args)
		proc = exec.Command(cfg.qemu, args...)
		// The w-binary's startup errors (bad args, SDL init) only ever reach
		// stderr; without this they vanish and a dead QEMU is undebuggable.
		ef, err := os.OpenFile(filepath.Join(cfg.vmDir, "qemu-stderr.log"),
			os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644) // per-attempt: the memory ladder sniffs it
		if err == nil {
			proc.Stdout = ef
			proc.Stderr = ef
		}
		guestLaunchInProgress.Store(true)
		if windowsSessionEnding.Load() {
			guestLaunchInProgress.Store(false)
			if ef != nil {
				ef.Close()
			}
			return false
		}
		guestExitedCleanly.Store(false)
		if err := recordGuestExit(cfg.vmDir, false, "running"); err != nil {
			logf("could not record guest start: %v", err)
		}
		if windowsSessionEnding.Load() {
			guestLaunchInProgress.Store(false)
			if ef != nil {
				ef.Close()
			}
			return false
		}
		err = proc.Start()
		// QEMU inherits its own handle. Closing ours per attempt keeps retries
		// and guest reboots from leaking one handle each.
		if ef != nil {
			ef.Close()
		}
		if err != nil {
			guestLaunchInProgress.Store(false)
			fatal(uiTextWith("fatal.qemu.start", map[string]string{"error": err.Error()}))
		}
		qemuPid.Store(uint32(proc.Process.Pid))
		guestLaunchInProgress.Store(false)
		exited := make(chan error, 1)
		go func() {
			err := proc.Wait()
			if err != nil {
				logf("QEMU process exited with error: %v", err)
			}
			exited <- err
		}()

		// Do NOT touch QMP during early guest boot: a monitor connection in
		// the first seconds reliably wedges QEMU's main loop under WHPX (the
		// "launch wedge" - near-certain nested, intermittent on hardware).
		// Give the guest a head start, then probe gently.
		deadline := time.Now().Add(60 * time.Second)
		wait := 10 * time.Second
		startupDead := false
	probe:
		for qmp == nil && time.Now().Before(deadline) {
			select {
			case <-exited:
				startupDead = true
				if detail := qemuStartupFailureTail(cfg.vmDir); detail != "" {
					logf("QEMU startup failure (attempt %d):\n%s", attempt, detail)
				}
				// SDL supports capture and playback. Retain playback-only
				// DirectSound, then silent operation, for unavailable devices.
				if cfg.audio != "none" && audioUnavailable(cfg) {
					if cfg.audio == "sdl" {
						cfg.audio = "dsound"
					} else {
						cfg.audio = "none"
					}
					logf("QEMU exited at startup - retrying with audio backend %s", cfg.audio)
					break probe
				}
				fatal(uiTextWith("fatal.qemu.exited", map[string]string{"folder": cfg.vmDir}))
			case <-time.After(wait):
				wait = 3 * time.Second
				qmp = qmpConnect(qmpSupPort, 8*time.Second)
			}
		}
		if qmp != nil {
			guestUp.Store(true)
			defer qmp.close()
			return watch(cfg, qmp, exited)
		}
		qemuPid.Store(0)
		if !startupDead {
			logf("QEMU did not answer QMP within the startup timeout - killing and retrying")
			proc.Process.Kill()
			<-exited
		}
		time.Sleep(2 * time.Second)
	}
	fatal(uiTextWith("fatal.qemu.unhealthy", map[string]string{"count": fmt.Sprint(maxLaunchAttempts), "folder": cfg.vmDir}))
	return false
}

func watch(cfg *config, qmp *qmpConn, exited <-chan error) bool {
	logf("supervisor: watching guest lifecycle")
	lines := qmp.readLines()
	reason := ""
	cleanExit := false
	silence := qmpSilence{}
	hangReported := false
	tick := 0
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	procDown := false
	for reason == "" && !procDown {
		if guestReady.Swap(false) {
			logf("guest userspace announced ready")
		}
		select {
		case <-exited:
			procDown = true
		case line, ok := <-lines:
			if !ok {
				// 改変: 元は起動完了後なら復旧ダイアログを出して VM を残す。ここではログだけ。
				lines = nil
				logf("supervisor: the QMP event stream closed; waiting for QEMU to exit")
				break
			}
			silence.answered()
			hangReported = false
			var status struct {
				Return *vmRuntimeStatus `json:"return"`
				Event  string           `json:"event"`
			}
			if json.Unmarshal([]byte(line), &status) == nil && status.Event != "" {
				logf("qmp event: %s", status.Event)
			}
			if r := shutdownReason(line); r != "" {
				reason = r
				cleanExit = cleanGuestShutdown(line)
			}
		case <-ticker.C:
			tick++
			if tick%5 == 0 && lines != nil {
				if err := qmp.writeLine(`{"execute":"query-status"}`); err != nil && !hangReported {
					// 改変: 元は起動完了後なら復旧ダイアログ。ここではログだけ。
					hangReported = true
					logf("supervisor: QMP query failed: %v", err)
				}
				if silence.probe() && !hangReported {
					hangReported = true
					logf("supervisor: QEMU stopped answering QMP")
				}
			}
		}
	}
	// Collect a SHUTDOWN the pending read completed with after the loop ended.
	if reason == "" && lines != nil {
		for {
			select {
			case line, ok := <-lines:
				if !ok {
					lines = nil
				} else if r := shutdownReason(line); r != "" {
					reason = r
					cleanExit = cleanGuestShutdown(line)
				}
				if reason != "" || lines == nil {
					goto drained
				}
			case <-time.After(500 * time.Millisecond):
				goto drained
			}
		}
	}
drained:
	if !procDown {
		waitExit(exited, 15*time.Second, cfg)
	}
	guestUp.Store(false)
	qemuPid.Store(0)
	// A QEMU wedged during the guest's reset can die without ever delivering
	// its SHUTDOWN event, making reboot and poweroff indistinguishable over
	// QMP (and the wedge also loses the serial file's final flush, so the
	// kernel's "Restarting system" line can't be sniffed either). The guest
	// image closes the gap: a shutdown unit reports reboot intent on the
	// lifecycle port before the network goes down.
	if reason == "" && pendingReboot.Swap(false) {
		reason = "reboot"
	}
	if err := recordGuestExit(cfg.vmDir, cleanExit, reason); err != nil {
		logf("could not record guest exit: %v", err)
	}
	guestExitedCleanly.Store(cleanExit)
	if windowsSessionEnding.Load() {
		return false
	}
	if reason == "reboot" {
		logf("guest rebooted - relaunching")
		return true
	}
	if reason == "" {
		logf("QEMU exited without a guest shutdown event")
	} else {
		logf("guest powered off (%s)", reason)
	}
	return false
}

// runLifecycleListener receives the guest's shutdown intent: the image's
// reboot-notify unit connects to 10.0.2.2:4450 (this listener via
// user-net) and says "reboot" when the guest is rebooting rather than
// powering off.
func runLifecycleListener() {
	l, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", lifecyclePort))
	if err != nil {
		fatal(uiTextWith("fatal.port.lifecycle", map[string]string{"port": fmt.Sprint(lifecyclePort)}))
	}
	go func() {
		gate := make(chan struct{}, 4)
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			select {
			case gate <- struct{}{}:
				go func() {
					defer func() { <-gate }()
					serveLifecycle(c, loopbackPeerPID, lifecyclePIDFromQEMU, nil, func(line string, c net.Conn) {
						switch line {
						case "shutdown":
							guestCompositorHealth.stop()
							logf("guest announced shutdown")
						case "reboot":
							guestCompositorHealth.stop()
							logf("guest announced reboot")
							pendingReboot.Store(true)
						case "ready":
							guestReady.Store(true)
						}
					})
				}()
			default:
				c.Close()
			}
		}
	}()
}
