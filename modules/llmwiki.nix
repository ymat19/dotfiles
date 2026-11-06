{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  workspace = "${config.home.homeDirectory}/llm-wiki";

  # 上流の docker/local は 2026-10-16 以降、web の型チェックが参照する tests/fixtures を
  # .dockerignore で落としていてビルドできない。外部 PR は取り込まれていないため手元で直す
  src = pkgs.applyPatches {
    name = "llmwiki-src";
    src = inputs.llmwiki;
    patches = [ ../patches/llmwiki-docker-fixtures.patch ];
  };
  image = "llmwiki:${builtins.substring 11 32 "${src}"}";

  llmwiki-image = pkgs.writeShellApplication {
    name = "llmwiki-image";
    runtimeInputs = with pkgs; [
      docker
      coreutils
      gnugrep
      findutils
    ];
    text = ''
      if docker image inspect ${image} >/dev/null 2>&1; then
        exit 0
      fi
      # 既定のビルダーは全コアを使い、buildkit には並列度を絞る引数も無いため、CPU を半分に固定したビルダーを使う
      if ! docker buildx inspect llmwiki >/dev/null 2>&1; then
        docker buildx create --name llmwiki --driver docker-container \
          --driver-opt "cpuset-cpus=0-$(($(nproc) / 2 - 1))"
      fi
      docker buildx build --builder llmwiki --load -t ${image} -f ${src}/docker/local/Dockerfile ${src}
      # buildkit のコンテナはビルド後も常駐して数百 MB を使い続ける
      docker buildx stop llmwiki
      docker image ls llmwiki --format '{{.Repository}}:{{.Tag}}' | grep -vx ${image} | xargs -r docker image rm
    '';
  };

  # セッション記録は ~/.claude と ~/.codex に既に残っているため、記録用の hook は置かずソースへ変換するだけにする。
  # wiki への反映は上流 README が勧める定期実行のプロンプトそのままで、何をどう残すかは guide に任せる
  llmwiki-compile = pkgs.writeShellApplication {
    name = "llmwiki-compile";
    runtimeInputs = with pkgs; [ python3 ];
    text = ''
      python3 ${../configs/llmwiki/digest.py} ${workspace}
      cd ${workspace}
      ${config.home.profileDirectory}/bin/claude -p ${lib.escapeShellArg routinePrompt} </dev/null
    '';
  };

  # https://github.com/lucasastorian/llmwiki#getting-started の「A routine prompt that works well」
  routinePrompt = "Read the guide. Find everything added to the workspace since your last run — new sources, clips, and highlights. For each one, read it and update the wiki: write new pages where they're warranted, fold new material into existing pages, and fix any cross-references or citations it affects.";

  # systemd は Exec 行の $ を自前で展開するため、待機ループはスクリプトに分ける
  llmwiki-wait = pkgs.writeShellScript "llmwiki-wait" ''
    for _ in $(${pkgs.coreutils}/bin/seq 120); do
      ${pkgs.curl}/bin/curl -sf http://127.0.0.1:3000/api/health >/dev/null && exit 0
      sleep 1
    done
    exit 1
  '';
in
{
  # 上流 docker/local/README.md の起動方法どおり。Web は本番ビルドで、MCP は /mcp の HTTP になる
  systemd.user.services.llmwiki = {
    Unit = {
      Description = "LLM Wiki (local mode, docker)";
      Requires = [ "docker.service" ];
      After = [ "docker.service" ];
    };
    Service = {
      Environment = [ "DOCKER_HOST=unix://%t/docker.sock" ];
      ExecStartPre = [
        "${llmwiki-image}/bin/llmwiki-image"
        "-${pkgs.docker}/bin/docker rm -f llmwiki"
        "${pkgs.coreutils}/bin/mkdir -p ${workspace}"
      ];
      # rootless docker ではコンテナの root がホストのユーザーに対応するので、README の -u は付けない
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name llmwiki -p 127.0.0.1:3000:3000 -v ${workspace}:/workspace ${image}";
      # 夜間ジョブの claude は起動時に MCP へつなぐため、応答できるようになるまで active にしない
      ExecStartPost = "${llmwiki-wait}";
      ExecStop = "${pkgs.docker}/bin/docker stop llmwiki";
      # 初回はイメージのビルドを含む
      TimeoutStartSec = "30min";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.llmwiki-compile = {
    Unit = {
      Description = "Compile agent sessions into LLM Wiki";
      # MCP はコンテナが提供する
      Wants = [ "llmwiki.service" ];
      After = [ "llmwiki.service" ];
      # 実行中の oneshot を switch が再起動しようとすると、終わるまで activation ごと待たされる
      X-RestartIfChanged = false;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${llmwiki-compile}/bin/llmwiki-compile";
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/usr/bin:/bin"
      ];
      Nice = 19;
      # 初回はバックログを全件処理するため時間の上限を設けない
      TimeoutStartSec = "infinity";
    };
  };

  systemd.user.timers.llmwiki-compile = {
    Unit.Description = "Nightly LLM Wiki compile";
    Timer = {
      OnCalendar = "*-*-* 03:00:00";
      # 夜間に電源が落ちていたノートでも、次に起動したときに実行する
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  programs.mcp.servers.llmwiki.url = "http://localhost:3000/mcp";
}
