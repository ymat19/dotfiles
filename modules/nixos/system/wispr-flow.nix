{
  pkgs,
  lib,
  username,
  ...
}:

let
  # Wispr Flow は公式には macOS/Windows のみ。非公式 Linux ポート
  # (wispr-flow-linux/wispr-flow-linux) のリリース成果物を使う。
  appVersion = "1.6.7";
  pkgRelease = "1.0.3";
  version = "${appVersion}-${pkgRelease}";
  # リリースタグに '+' が含まれるため URL では %2B のままにする
  releaseTag = "v${pkgRelease}%2Bwispr${appVersion}";

  arch = if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64";
  hashes = {
    x86_64 = "sha256-T9/evAykYnc20TVc7sX3Bwf8aTkTkxEtDr8FNavIMfA=";
    aarch64 = "sha256-oGiM2poO701pPh9MtZaXbdMcEN+U99BGHi/mJ9ypIO4=";
  };

  pname = "wispr-flow";

  src = pkgs.fetchurl {
    url = "https://github.com/wispr-flow-linux/wispr-flow-linux/releases/download/${releaseTag}/wispr-flow-${version}-${arch}.AppImage";
    hash = hashes.${arch};
  };

  extracted = pkgs.appimageTools.extract { inherit pname version src; };

  # 上流の flake (packages.wispr-flow-fhs) は使わない。
  # helper の fetchFromGitHub が lib.fakeHash のまま、独自入手した Windows
  # インストーラ .exe を WISPR_FLOW_EXE で渡す --impure 前提、かつ
  # better-sqlite3 のネイティブモジュールを再ビルドしないため DB 機能が壊れる、
  # と上流自身が明記している。リリースの AppImage は CI で
  # rebuild-native-modules.sh を通った検証済みバイナリなのでこちらを包む。
  #
  # 副作用として chrome-sandbox が setuid root にならず（nix store に setuid は
  # 置けない）、AppRun が --no-sandbox で起動する。`--doctor` はここを FAIL と
  # 報告するが、setuid sandbox に切り替える道はない: AppRun の 'appimage' モード
  # が --no-sandbox を固定で付けており、外すと Electron が起動拒否に倒れる。
  wispr-flow = pkgs.appimageTools.wrapAppImage {
    inherit pname version;
    src = extracted;

    # helper が直接叩く外部コマンド。クリップボード系は Wayland では必須依存。
    extraPkgs =
      p: with p; [
        wl-clipboard
        xclip
        xsel
        dbus
        at-spi2-core
        systemd # udevadm
        glib # gsettings
      ];

    extraInstallCommands = ''
      install -Dm444 ${extracted}/ai.wisprflow.WisprFlow.desktop \
        -t $out/share/applications
      # AppImage 内の Exec=AppRun は AppDir 前提のパス。ラッパー名に差し替える。
      substituteInPlace $out/share/applications/ai.wisprflow.WisprFlow.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'
      cp -r ${extracted}/usr/share/icons $out/share/

      # 上流の 70-wispr-flow-uinput.rules と同内容。services.udev.packages で
      # 拾わせる。services.udev.extraRules には書かない: hardware.uinput.enable
      # が同じオプションに GROUP="uinput" の行を足すため、マージ順で GROUP が
      # どちらに倒れるか決まらない。ファイル名でソート順が確定する 70- に置く。
      mkdir -p $out/lib/udev/rules.d
      cat > $out/lib/udev/rules.d/70-wispr-flow-uinput.rules <<'UDEV'
      KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess", GROUP="input", MODE="0660"
      SUBSYSTEM=="input", KERNEL=="event*", TAG+="uaccess", GROUP="input", MODE="0660"
      UDEV

      # helper 自身の注入用仮想デバイスだけは helper から読めなくする。
      # helper は注入の前後で「物理的に押されている修飾キー」を全 event* への
      # EVIOCGKEY で調べて離し→押し直すが、自分の仮想デバイスも対象に含めてしまう。
      # 一度でも修飾キーを押し直すと、それを次回「押されている」と読んで再び押し直す
      # 自己ラッチになり、音声入力のたびに Super/Ctrl/Shift が押しっぱなしになる。
      # 上流 helper に除外処理が無いので、読めないデバイスはスキップされる挙動を使う。
      # uaccess の ACL 付与（73-seat-late）より前でタグを外す必要があるので 71-。
      cat > $out/lib/udev/rules.d/71-wispr-flow-helper-private.rules <<'UDEV'
      SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Wispr Flow Linux Helper", TAG-="uaccess", GROUP="root", MODE="0600"
      UDEV
    '';

    meta = {
      description = "Wispr Flow voice dictation for Linux (unofficial build)";
      homepage = "https://github.com/wispr-flow-linux/wispr-flow-linux";
      license = lib.licenses.unfree;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      mainProgram = pname;
    };
  };
in
{
  environment.systemPackages = [ wispr-flow ];

  # /dev/uinput への write（キーストローク注入）と /dev/input/event* の read
  # （push-to-talk のグローバルキー監視）が helper の動作要件。AppImage は root
  # の postinst を持てないので、パッケージが同梱した rule を udev に読ませる。
  boot.kernelModules = [ "uinput" ];
  services.udev.packages = [ wispr-flow ];

  # niri は wlroots 系の汎用 Wayland バックエンド扱いで、アクティブアプリの
  # 判定と選択テキストの取得に AT-SPI を使う。D-Bus サービスが無いと常に空になる。
  services.gnome.at-spi2-core.enable = true;

  # Wispr は押下のたびにマイクを開き直すが、WirePlumber は未使用 5 秒で入力を
  # suspend する。USB マイク（PowerConf で実測）は suspend 復帰後の約 1.8 秒間
  # 無音(0)しか返さず、話し始めが毎回欠落する。Wispr 側に常時オープンの設定は
  # 無いので、入力デバイスを suspend させないことで復帰待ちそのものを無くす。
  services.pipewire.wireplumber.extraConfig."51-wispr-no-input-suspend" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "node.name" = "~alsa_input.*"; } ];
        actions.update-props."session.suspend-timeout-seconds" = 0;
      }
    ];
  };

  # helper は KEY_A..KEY_Z を持つデバイスしか監視せず、evdev→VK の変換表にも
  # BTN_* が無い。アプリ側でマウスボタン(4099 等)をショートカットに登録できても
  # helper からイベントが届かず反応しない。xremap にマウスも掴ませてサイドボタンを
  # キーに変換し、xremap の仮想キーボード経由で helper に見せる。
  #
  # 単独キーにしないのは、Wispr が修飾キーを含まないショートカットも、修飾キー
  # 単独のショートカットも登録拒否するため。修飾キー＋空きキーを同時に押下させる。
  # F20 以降は xkb が XF86AudioMicMute 等に割り当てており niri のバインドを誤爆する
  # ので F19。右 Ctrl は CapsLock→左 Ctrl と区別でき、既存ショートカットと衝突しない。
  services.xremap.mouse = true;

  # xremap が物理キーボード/マウスを grab するので、helper に届く入力は xremap の
  # 仮想デバイス経由だけになる。helper は起動時にしかデバイスを列挙しないため、
  # rebuild 等で xremap が再起動して仮想デバイスが作り直されると入力を失う。
  # 上流 helper に再スキャン機構が無いので、仮想デバイスの出現時に helper を
  # kill し、本体の自動 relaunch で列挙し直させる。
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="xremap", RUN+="${pkgs.procps}/bin/pkill -f wispr-flow-linux-helper"
  '';

  services.xremap.config.modmap = [
    {
      name = "Mouse side button to Ctrl_R+F19 (Wispr Flow push-to-talk)";
      remap."BTN_SIDE" = [
        "Ctrl_R"
        "F19"
      ];
    }
    # 口述後の送信をマウスだけで完結させる。Wispr の "Press Enter" 機能は使わない:
    # helper は入力デバイスを grab しないので元のキーも素通しされ、しかも同じく
    # マウスボタンを検知できない。
    {
      name = "Mouse extra button to Enter (send after dictation)";
      remap."BTN_EXTRA" = "Enter";
    }
  ];

  # helper は貼り付けを常に Ctrl+V で注入するが、Alacritty は Ctrl+V を ^V(0x16)
  # として中のアプリへ渡すだけなので、Vim/zsh では quoted-insert の "^" しか出ない
  # （Claude Code は ^V を受けて自前でクリップボードを読むので動いていた）。
  # Alacritty 側で Ctrl+V を Paste に割り当てると Vim の矩形選択等を失うため、
  # xremap が helper の仮想デバイスも掴んでいることを利用し、helper 由来の
  # Ctrl+V だけをターミナルでは Ctrl+Shift+V に差し替える。
  services.xremap.config.keymap = [
    {
      name = "Wispr Flow paste into terminals as Ctrl+Shift+V";
      device.only = [ "Wispr Flow Linux Helper" ];
      application.only = [ "/^(Alacritty|alacritty-scratch)$/" ];
      remap."C-v" = "C-Shift-v";
    }
  ];

  home-manager.users.${username} = {
    # helper も起動時に toolkit-accessibility を立てようとするが best-effort で、
    # 失敗すると選択テキストが黙って空になる。GTK 側の既定が false なので
    # 明示的に有効化して、取得できるかどうかを運任せにしない。
    dconf.settings."org/gnome/desktop/interface".toolkit-accessibility = true;

    # 録音インジケータ（自前実装）。
    #
    # 本体の Status ウィンドウ（透明オーバーレイ）は、矩形全体でポインタ入力を
    # 食う。以下を実測して全て効果が無いことを確認済み:
    #   - αしきい値の引き上げ（上流 PR #73）
    #   - 判定の常時真化（setIgnoreMouseEvents を無条件 true に）
    #   - override-redirect の解除
    #   - X の input shape を外部から 1x1 に設定
    # アプリが「入力を受けない」と宣言してもコンポジタがポインタを渡しており、
    # 壊れているのはアプリより下（Electron/Xwayland の input region 伝播）。
    # Electron PR #51769 と xwayland-satellite #429 待ちで、今は直せない。
    #
    # そこで本体ウィンドウは niri の window-rule で専用ワークスペースへ隔離し
    # （configs/niri-base.kdl）、見た目だけをここで描く。layer-shell の mask を
    # 空にすると入力領域が空になり、仕様上クリックを一切受けない。
    xdg.configFile."wispr-indicator/shell.qml".source = ../../../configs/wispr-indicator/shell.qml;

    systemd.user.services.wispr-indicator = {
      Unit = {
        Description = "Wispr Flow recording indicator (layer-shell overlay)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.quickshell}/bin/quickshell -p %h/.config/wispr-indicator/shell.qml";
        # 録音判定に pw-dump / jq / grep を使う
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.bash
              pkgs.pipewire
              pkgs.jq
              pkgs.gnugrep
              pkgs.coreutils
            ]
          }"
        ];
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
