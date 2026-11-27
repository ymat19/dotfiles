{
  description = "Home Manager configuration of ymat19";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nixos-apple-silicon.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xremap.url = "github:xremap/nix-flake";
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    try.url = "github:ymat19/try";
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents-nix.url = "github:numtide/llm-agents.nix";
    niri-scratchpad = {
      url = "github:gvolpe/niri-scratchpad";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agent-skills-nix = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr = {
      url = "github:herdrdev/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stop-describing-ui = {
      url = "github:artouc/stop-describing-ui";
      flake = false;
    };
    modern-web-guidance = {
      url = "github:GoogleChrome/modern-web-guidance";
      flake = false;
    };
    llmwiki = {
      url = "github:lucasastorian/llmwiki";
      flake = false;
    };
    nixpkgs-node.url = "github:nixos/nixpkgs/nixos-unstable";
    # Try Omarchy for Windows。winq-emu のランチャーとゲスト側のスクリプトの上流。
    # Windows で試験してから上げるので、URL にコミットを固定して自動更新で動かないようにしている。
    try-omarchy-windows = {
      url = "github:omacom/try-omarchy-windows/5b1617edaef21942de08c1c64575cd7638f4808a";
      flake = false;
    };
    rea = {
      url = "github:morluto/rea/rea-agents-6.8.0";
      flake = false;
    };
  };

  outputs = inputs @ { nixpkgs, home-manager, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
            ];
            shellhook = ''
              $SHELL
            '';
          };
          # winq-emu を Windows で起動するランチャー（niri-vm.exe）。Go のクロスビルドなので
          # Nix のある任意の Linux（winq-emu の VM 自身を含む）でビルドできる。docs/winq-emu.md を参照。
          packages.winq-launcher = pkgs.callPackage ./scripts/winq/launcher {
            tryOmarchy = inputs.try-omarchy-windows;
          };
        }
      ) // (
      let
        getNixFiles = import ./lib/get-nix-files.nix;

        requireStandalone = !builtins.pathExists "/etc/nixos";

        # for standalone home-manager
        system = builtins.currentSystem;
        pkgs = nixpkgs.legacyPackages.${system};
        envUsername = builtins.getEnv "USER";
        envHomeDir = builtins.getEnv "HOME";

        # for WSL: Windows ドライブが /mnt/c にマウントされていれば WSL とみなす。
        # PATH ベースの判定はシェル初期化前（Claude Code など）に評価すると false に倒れるため使わない。
        onWSL = builtins.pathExists "/mnt/c/Windows";

        # for NixOS
        nixOSUserName = "ymat19";
        hostPlatforms = {
          ymat19 = "x86_64-linux";
          main = "x86_64-linux";
          mini = "x86_64-linux";
          dyna = "x86_64-linux";
          air = "aarch64-linux";
          winq-emu = "x86_64-linux";
        };
        nixOSSpecialArgs = {
          inherit inputs;
          username = nixOSUserName;
          homeDirectory = "/home/${nixOSUserName}";
          onWSL = onWSL;
          onNixOS = true;
          hasBattery = false;
        };
        # winq-emu は WINQ-EMU（Windows 上の QEMU）で動く VM。イメージは WSL 上で
        # ビルドすることがあるので、ビルド機の onWSL 判定に引きずられないよう固定する。
        winqEmuSpecialArgs = nixOSSpecialArgs // { onWSL = false; };
        mkNixOSModules = mkNixOSModulesWith nixOSSpecialArgs;
        mkNixOSModulesWith = args: envName: [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          ({ pkgs, ... }: {
            nixpkgs.hostPlatform = hostPlatforms.${envName};
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${nixOSUserName} = import ./home.nix;
            home-manager.extraSpecialArgs = args // { inherit envName; };

            # 管理外の実ファイルを退避する方法。backupFileExtension（固定拡張子）は使わない。
            # Claude Code のように自分の設定ファイルを実行時に書き換えるツールがあると、
            # home-manager の store symlink が実ファイルに化けて毎回この退避が走る。
            # 固定拡張子だと 2 回目に前回の退避先と衝突し、activation ごと失敗する
            # （実際に ~/.claude/settings.json.backup で switch が落ちた）。
            # タイムスタンプで一意にして、衝突そのものを起こさない。
            home-manager.backupCommand = pkgs.writeShellScript "hm-backup" ''
              set -euo pipefail
              target=$1
              ${pkgs.coreutils}/bin/mv -f -- \
                "$target" "$target.backup-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
            '';
          })
        ] ++ (if args.onWSL then [ ] else
        ([
          inputs.xremap.nixosModules.default
          ./modules/nixos/system/xremap.nix
          ./modules/nixos/system/thunar.nix
          ./modules/nixos/system/poiter-util.nix
          ./modules/nixos/system/wispr-flow.nix
          ./modules/nixos/system/codex-desktop.nix
        ]));

        # /etc/nixos の無い環境（WSL の Ubuntu、イメージから起動した直後の VM）でも
        # ビルドできるよう、winq-emu だけは requireStandalone に関係なく出力する。
        winqEmuSystem = nixpkgs.lib.nixosSystem {
          modules = (mkNixOSModulesWith winqEmuSpecialArgs "winq-emu") ++ [
            ./modules/nixos/system/no-sleep.nix
            ./nixos-configurations/winq-emu.nix
          ];
          specialArgs = winqEmuSpecialArgs // {
            envName = "winq-emu";
          };
        };
      in
      { } // (if requireStandalone then {
        nixosConfigurations.winq-emu = winqEmuSystem;
        homeConfigurations.${envUsername} = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
          extraSpecialArgs = {
            inherit inputs;
            username = envUsername;
            homeDirectory = envHomeDir;
            onNixOS = false;
            onWSL = onWSL;
            envName = "";
          };
        };
      } else {
        nixosConfigurations = {
          ${nixOSUserName} = nixpkgs.lib.nixosSystem {
            modules = mkNixOSModules nixOSUserName;
            specialArgs = nixOSSpecialArgs // {
              envName = nixOSUserName;
            };
          };
          main = nixpkgs.lib.nixosSystem {
            modules = (mkNixOSModules "main") ++ [
              ./modules/nixos/system/nvidia.nix
              ./modules/nixos/system/steam.nix
              ./modules/nixos/system/bedroom-audio.nix
              ./modules/nixos/system/discord.nix
            ];
            specialArgs = nixOSSpecialArgs // {
              envName = "main";
            };
          };
          mini = nixpkgs.lib.nixosSystem {
            modules = (mkNixOSModules "mini") ++ [
              ./modules/nixos/system/steam.nix
            ];
            specialArgs = nixOSSpecialArgs // {
              envName = "mini";
            };
          };
          dyna = nixpkgs.lib.nixosSystem {
            modules = (mkNixOSModules "dyna") ++ [
              ./modules/nixos/system/dotnet.nix
              ./modules/nixos/system/no-sleep.nix
              { home-manager.extraSpecialArgs = nixpkgs.lib.mkForce (nixOSSpecialArgs // { envName = "dyna"; hasBattery = true; }); }
            ];
            specialArgs = nixOSSpecialArgs // {
              envName = "dyna";
            };
          };
          air = nixpkgs.lib.nixosSystem {
            modules = (mkNixOSModules "air") ++ [
              inputs.apple-silicon.nixosModules.default
              { home-manager.extraSpecialArgs = nixpkgs.lib.mkForce (nixOSSpecialArgs // { envName = "air"; hasBattery = true; }); }
            ];
            specialArgs = nixOSSpecialArgs // {
              envName = "air";
            };
          };
          winq-emu = winqEmuSystem;
        };
      })
    );
}
