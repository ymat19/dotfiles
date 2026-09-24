// Wispr Flow の録音インジケータ。
//
// 本体の Status ウィンドウ（Electron の透明オーバーレイ）は矩形全体でポインタ入力を
// 食う。以下は全て実測して効果が無いことを確認済み:
//   - αしきい値の引き上げ（上流 PR #73）
//   - 判定の常時真化（setIgnoreMouseEvents を無条件 true に）
//   - override-redirect の解除
//   - X の input shape を外部から 1x1 に設定
// アプリが「入力を受けない」と宣言してもコンポジタがポインタを渡すため、アプリ側では
// 直せない（Electron PR #51769 / xwayland-satellite #429 待ち）。
//
// 本体ウィンドウの描画内容をそのまま複製する案は、niri が toplevel 単位のキャプチャに
// 必要な ext_image_copy_capture_v1 を実装しておらず（zwlr_screencopy は出力単位のみ）
// 成立しなかった。そのため本体は niri の window-rule で専用ワークスペース "wispr" へ
// 隔離し（configs/niri-base.kdl）、インジケータはここで描き直す。
//
// この layer-shell サーフェスは mask を空にしてあるため、仕様上ポインタ入力を一切
// 受けない。
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root
    property bool recording: false

    // wispr-flow がマイクを掴んでいるかを PipeWire から判定する。
    // ログ形式に依存しないので上流の更新で壊れない。
    //
    // pw-dump を定期実行しない: 毎回グラフ全体（数百 KB）を JSON 化するので、
    // 0.4 秒間隔で CPU 1 コアの 1 割前後を常時食っていた。監視モードで差分だけ
    // 受け取り、入力ストリームの一覧を jq 側で保持する（削除は info: null で届く）。
    Process {
        id: probe
        running: true
        command: ["/bin/sh", "-c", "pw-dump -m -N | jq -n --unbuffered -r \"$0\"", `
            foreach inputs as $batch ({};
              reduce $batch[] as $o (.;
                if $o.info == null then del(.[$o.id | tostring])
                elif $o.info.props then
                  .[$o.id | tostring] = (
                    $o.info.props["media.class"] == "Stream/Input/Audio"
                    and ((($o.info.props["application.process.binary"] // "")
                          + " " + ($o.info.props["application.name"] // ""))
                         | test("wispr"; "i")))
                else . end);
              if any(.[]; .) then 1 else 0 end)`]
        stdout: SplitParser {
            onRead: data => root.recording = (data.trim() === "1")
        }
        // PipeWire の再起動などで監視が切れたら張り直す
        onExited: {
            root.recording = false;
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: probe.running = true
    }

    // 画面の抜き差し（ドック切断など）で出力が消えると、特定の screen に紐づいた
    // PanelWindow はプレースホルダ画面に移ったまま戻らない。screens を model にして
    // 出力の出現ごとに作り直させる。
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.bottom: true
            margins.bottom: 40
            implicitWidth: 140
            implicitHeight: 36
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // 全画面ウィンドウにも覆われないよう Overlay レイヤーに置く
            WlrLayershell.layer: WlrLayer.Overlay
    
            // 空マスク = 入力領域なし。クリックを食わないことの保証。
            mask: Region {}
    
            Rectangle {
                anchors.centerIn: parent
                width: 104
                height: 28
                radius: height / 2
                visible: root.recording
                color: "#cc1f2430"
                border.color: "#7aa2f7"
                border.width: 1
    
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#f7768e"
                        SequentialAnimation on opacity {
                            running: root.recording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Flow"
                        color: "#c0caf5"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
