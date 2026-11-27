{ pkgs, ... }:

# main の寝室用の音声出力。寝室のモニタ（DP-3）でゲームパッドだけで Steam を遊ぶとき、
# Steam とゲームの音は寝室へ、デスクのブラウザなどの音は既定の出力（デスクの PowerConf）へ分ける。
#
# Steam は仮想シンク「寝室」（node.name = bedroom）へ出す（steam.nix の PULSE_SINK）。
# 「寝室」の実際の出力先は bedroom-audio-router が選ぶ。BT の出力がつながっていればそちら、
# 無ければ寝室のモニタの HDMI。
let
  # 寝室のモニタ（ASUS VG259、DP-3）の HDMI 音声。TU116 の 2 本目の HDMI 出力にあたる。
  hdmiCard = "alsa_card.pci-0000_01_00.1";
  hdmiProfile = "output:hdmi-stereo-extra1";
  hdmiSink = "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1";

  router = pkgs.writeShellApplication {
    name = "bedroom-audio-router";
    runtimeInputs = with pkgs; [
      pipewire
      wireplumber
      jq
      coreutils
    ];
    text = ''
      last=""

      reconcile() {
        local dump card profile out target
        dump=$(pw-dump)

        # TU116 の ALSA プロファイルは HDMI を 1 本ずつしか出せない。寝室のモニタの信号が途切れると
        # WirePlumber が別のプロファイルへ移ることがあるので、使える状態なら寝室側へ戻す。
        if ! jq -e --arg s "${hdmiSink}" 'any(.[]; .info.props["node.name"]? == $s)' <<<"$dump" >/dev/null; then
          read -r card profile < <(jq -r --arg c "${hdmiCard}" --arg p "${hdmiProfile}" '
            .[] | select(.type == "PipeWire:Interface:Device" and .info.props["device.name"]? == $c)
            | [.id, (.info.params.EnumProfile[]? | select(.name == $p and .available != "no") | .index)]
            | select(length == 2) | "\(.[0]) \(.[1])"' <<<"$dump") || true
          if [ -n "''${card:-}" ]; then
            wpctl set-profile "$card" "$profile" || true
          fi
        fi

        out=$(jq -r '.[] | select(.info.props["node.name"]? == "bedroom.output") | .id' <<<"$dump")
        [ -n "$out" ] || return 0

        target=$(jq -r '
          [.[] | select(.info.props["media.class"]? == "Audio/Sink")
               | .info.props["node.name"] | select(startswith("bluez_output."))] | first // empty' <<<"$dump")
        target=''${target:-${hdmiSink}}

        # ノード ID は PipeWire の再起動で変わるので、ID ごとに覚える。
        if [ "$last" != "$out:$target" ]; then
          echo "bedroom.output ($out) -> $target"
          pw-metadata -n default "$out" target.object "$target" >/dev/null
          last="$out:$target"
        fi
      }

      # pw-dump --monitor でイベント駆動にしないのは、何も起きていなくても毎秒 2000 行ほど流れ続け、
      # 読むだけで CPU を 1 コアの 12% 食ったため（実測）。1 回の判定は 25ms 程度なので 3 秒おきに見る。
      # PipeWire が落ちると pw-dump が失敗して終了し、systemd が再起動する。
      while true; do
        reconcile
        sleep 3
      done
    '';
  };
in
{
  services.pipewire.extraConfig.pipewire."60-bedroom-sink" = {
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "寝室";
          "capture.props" = {
            "node.name" = "bedroom";
            "media.class" = "Audio/Sink";
            "audio.position" = [
              "FL"
              "FR"
            ];
          };
          "playback.props" = {
            "node.name" = "bedroom.output";
            "audio.position" = [
              "FL"
              "FR"
            ];
            # node.dont-fallback は付けない。PipeWire の起動直後は HDMI のシンクがまだ無く、
            # 付けていると WirePlumber がストリームにエラーを返し、loopback ごと消える（実測）。
            # 出力先が無い間は既定の出力へ流れるが、bedroom-audio-router が付け替える。
            "target.object" = hdmiSink;
          };
        };
      }
    ];
  };

  systemd.user.services.bedroom-audio-router = {
    description = "寝室用の仮想シンクの出力先を BT か寝室のモニタに向ける";
    wantedBy = [ "pipewire.service" ];
    after = [
      "pipewire.service"
      "wireplumber.service"
    ];
    bindsTo = [ "pipewire.service" ];
    # 失敗し続けるときは再起動を諦めて止まる。
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
    };
    serviceConfig = {
      ExecStart = "${router}/bin/bedroom-audio-router";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
