{ ... }:

{
  programs.zsh.zsh-abbr = {
    enable = true;
    abbreviations = {
      # ===== 旧 alias 由来 =====
      tree = "lsd --tree";
      ne = "nb e";
      nl = "nb tasks";

      # ===== nix / home-manager =====
      nrs = "sudo nixos-rebuild switch --flake .#$(hostname) --impure";
      nrsb = "sudo nixos-rebuild switch -b backup --flake .#$(hostname) --impure";
      hms = "home-manager switch --flake . --impure";
      hmsb = "home-manager switch -b backup --flake . --impure";
      nfu = "nix flake update";

      # ===== 日常頻出 =====
      lg = "lazygit";
      cc = "claude -c";
      cr = "claude -r";
      cml = "claude mcp list";
      pd = "pnpm dev";

      # ===== ls (lsd) =====
      l = "lsd";
      ll = "lsd -l";
      la = "lsd -lA";
      lt = "lsd -lt";
      lS = "lsd -lS";

      # ===== navigation =====
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # ===== file ops =====
      md = "mkdir -p";
      rd = "rmdir";

      # ===== shell =====
      c = "clear";
      h = "history";
      q = "exit";
      reload = "exec zsh";

      # ===== editor =====
      v = "nvim";
      sv = "sudo -E nvim";

      # ===== system =====
      df = "df -h";
      du = "du -h";
      dud = "du -d 1 -h";
      myip = "curl -s https://ifconfig.me";
      ports = "ss -tulanp";

      # ===== git（lazygit で足りない隙間用） =====
      g = "git";
      gs = "git status";
      gd = "git diff";
      gds = "git diff --staged";
      gco = "git checkout";
      gcb = "git checkout -b";
      gsw = "git switch";
      gcm = "git commit -m";
      gp = "git push";
      gpl = "git pull";
      gf = "git fetch";
      gb = "git branch";
      glo = "git log --oneline --graph --decorate";

      # ===== pnpm =====
      p = "pnpm";
      pi = "pnpm install";
      pa = "pnpm add";
      pad = "pnpm add -D";
      pr = "pnpm run";
      pb = "pnpm build";
      pt = "pnpm test";
      px = "pnpm exec";
    };

    globalAbbreviations = {
      G = "| grep";
      L = "| less";
      H = "| head";
      T = "| tail";
      W = "| wc -l";
      S = "| sort";
      SU = "| sort -u";
      X = "| xargs";
      J = "| jq";
      N = "> /dev/null";
      NE = "2> /dev/null";
      NUL = "> /dev/null 2>&1";
      LL = "2>&1 | less";
      CP = "| wl-copy";
      V = "| vim -";
    };
  };
}
