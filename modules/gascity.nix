{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  llmPkgs = inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # エージェントを普段使いの herdr（既定セッション）に並べる。上流の herdr provider は
  # city 専用の名前付きセッションを前提にしていて、そのまま既定セッションに向けると
  # gc stop が herdr ごと止め、同名のワークスペースを乗っ取ってタブを閉じる
  gascity = llmPkgs.gascity.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/gascity-herdr-default-session.patch ];
  });

  cityDir = "${config.home.homeDirectory}/city";
  fragment = "${config.xdg.configHome}/gascity/city.toml";
  dotfilesRepo = "${config.programs.git.settings.ghq.root}/dotfiles";
  # 同時に動かす claude の上限。1 体数百 MB を使う
  maxActiveSessions = 3;

  # 共有チェックアウトは読み取り専用で、gc rig add は .gitignore 等を書き換えるため、
  # rig には city 配下の専用 clone を使う
  gc-rig-add = pkgs.writeShellApplication {
    name = "gc-rig-add";
    runtimeInputs = [
      gascity
      pkgs.git
    ];
    text = ''
      # usage: gc-rig-add <ローカルの checkout | clone URL> [rig 名]
      src=$1
      if [[ -d $src ]]; then
        src=$(realpath "$src")
        url=$(git -C "$src" remote get-url origin)
      else
        url=$src
      fi
      name=''${2:-$(basename "$src" .git)}
      dest=${cityDir}/rigs/$name

      if [[ ! -e $dest ]]; then
        # ローカルからの clone はオブジェクトをハードリンクで共有するので速い
        git clone "$src" "$dest"
        git -C "$dest" remote set-url origin "$url"
        git -C "$dest" fetch origin
      fi
      # gc のワークツリー作成は origin/HEAD から既定ブランチを引く
      git -C "$dest" remote set-head origin --auto
      # 名前から導く既定の prefix は ALog / ALogEP / ALogMain のような似た名前で衝突しうる
      prefix=$(tr -cd '[:alnum:]' <<<"$name" | tr '[:upper:]' '[:lower:]')
      adopt=()
      # 一度外した rig の作業記録を引き継ぐ
      [[ -d $dest/.beads ]] && adopt=(--adopt)
      gc --city ${cityDir} rig add "$dest" --name "$name" --prefix "$prefix" "''${adopt[@]}"
    '';
  };

  # city.toml は gc rig add が [[rigs]] を追記するので Nix 管理にできない。
  # 共通の設定だけを fragment に置き、include で取り込ませる
  gascity-city-init = pkgs.writeShellApplication {
    name = "gascity-city-init";
    runtimeInputs = [
      gascity
      gc-rig-add
      pkgs.gnugrep
      pkgs.gnused
      pkgs.coreutils
    ];
    text = ''
      if [[ ! -f ${cityDir}/city.toml ]]; then
        # 事前検査は PATH を見ずに決め打ちの場所だけを探すため、
        # /etc/profiles/per-user に入る claude を未導入と誤判定する
        gc init --template gascity --default-provider claude \
          --skip-provider-readiness --no-start ${cityDir}
      fi
      if ! grep -q '^include = ' ${cityDir}/city.toml; then
        sed -i '1i include = ["${fragment}"]\n' ${cityDir}/city.toml
      fi
      # fragment からも patches からも設定できない項目は、city.toml の該当テーブルに直接書く
      setKey() {
        sed -i "/^\[$1\]\$/,/^\[/{/^$2 = /d}" ${cityDir}/city.toml
        sed -i "/^\[$1\]\$/a $2 = $3" ${cityDir}/city.toml
      }
      setKey workspace max_active_sessions ${toString maxActiveSessions}
      # gc 既定は effort=max。"" は経路によって既定値の max に戻されるので段階を明示する
      setKey 'providers\.claude' option_defaults '{ effort = "high" }'
      for _ in $(seq 30); do
        gc supervisor status >/dev/null 2>&1 && break
        sleep 1
      done
      gc register ${cityDir}
      # dotfiles 以外は必要になったときに gc-rig-add で足す（rig ごとに dolt が常駐するため）
      if ! grep -qx 'name = "dotfiles"' ${cityDir}/city.toml; then
        gc-rig-add ${dotfilesRepo} dotfiles
      fi
    '';
  };
in
{
  home.packages = [
    gascity
    llmPkgs.beads
    gc-rig-add
    gascity-city-init
  ];

  home.sessionVariables.GC_CITY_PATH = cityDir;

  # include した fragment で合成されるのは [workspace] / [providers] の決め打ちの項目だけで、
  # max_active_sessions も option_defaults も黙って捨てられる（patches.providers でも未対応）。
  # その 2 つは gascity-city-init が city.toml に直接書く
  xdg.configFile."gascity/city.toml".text = ''
    [session]
    provider = "herdr"
  '';

  # gc start が生成するユニットは ExecStart にストアパスを焼き込み、更新しても古い gc のまま動き続ける
  systemd.user.services.gascity-supervisor = {
    Unit.Description = "Gas City machine supervisor";
    Service = {
      ExecStart = "${gascity}/bin/gc supervisor run";
      # 既定の control-group だと supervisor の停止がエージェントの子プロセスまで巻き込む
      KillMode = "process";
      Restart = "always";
      RestartSec = "5s";
      # API ポートを取り損ねた重複 supervisor の終了コード。再起動しても同じく失敗し続ける
      RestartPreventExitStatus = 3;
      StandardOutput = "append:%h/.gc/supervisor.log";
      StandardError = "append:%h/.gc/supervisor.log";
      Environment = [
        "GC_HOME=%h/.gc"
        "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin"
        "GC_SUPERVISOR_PRESERVE_SESSIONS_ON_SIGNAL=1"
        "GC_DISABLE_USAGE_METRICS=1"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  # 登録は ~/.gc に残るので起動ごとには要らない。supervisor が上がった後に一度通せばよい
  home.activation.gascityCity = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    run ${gascity-city-init}/bin/gascity-city-init \
      || echo "gascity: city の準備に失敗しました。gascity-city-init を手動で実行してください" >&2
  '';

  # gc start は自前のユニットを置いて enable する。その wants の symlink が home-manager の
  # ものとぶつかって switch を止めるうえ、残すと Nix 管理を外したときに古い gc が復活する
  home.activation.removeGcGeneratedSupervisorUnit = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    gcUnit="$HOME/.local/share/systemd/user/gascity-supervisor.service"
    gcWants="$HOME/.config/systemd/user/default.target.wants/gascity-supervisor.service"
    if [[ -L $gcWants && $(readlink "$gcWants") == "$gcUnit" ]]; then
      run rm -f "$gcWants"
    fi
    run rm -f "$gcUnit"
  '';

  # Gas City の gc が oh-my-zsh git プラグインの gc（git commit）に隠される
  programs.zsh.initContent = lib.mkAfter ''
    unalias gc 2>/dev/null
  '';

  # gc doctor は `git config --global beads.role` で確かめるが、--global は ~/.gitconfig があると
  # ~/.config/git/config を読まない。~/.gitconfig は読み取り専用なので、その生成内容に足す
  home.file.".gitconfig".text = lib.mkAfter ''
    [beads]
    	role = maintainer
  '';

  # beads が使う dolt は名義が無いと init で止まる。~/.dolt/config_global.json は dolt login が
  # 認証情報を書き込むので、.gitconfig のようにストアへの symlink にはできず値だけを揃える
  home.activation.configureDolt = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    let
      dolt = "${llmPkgs.dolt}/bin/dolt";
      inherit (config.programs.git.settings.user) name email;
    in
    ''
      run ${dolt} config --global --set user.name ${lib.escapeShellArg name} >/dev/null
      run ${dolt} config --global --set user.email ${lib.escapeShellArg email} >/dev/null
      run ${dolt} config --global --set metrics.disabled true >/dev/null
    ''
  );
}
