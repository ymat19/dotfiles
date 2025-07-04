{
  description = "Home Manager configuration of ymat19";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xremap.url = "github:xremap/nix-flake";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      # ...
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

        # for WSL
        path = builtins.getEnv "PATH";
        onWSL = builtins.match ".*system32.*" path != null;

        # for NixOS
        nixOSUserName = "ymat19";
        nixOSSpecialArgs = {
          inherit inputs;
          username = nixOSUserName;
          homeDirectory = "/home/${nixOSUserName}";
          onWSL = onWSL;
          onNixOS = true;
          hasBattery = false;
        };
        nixOSModules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${nixOSUserName} = import ./home.nix;
            home-manager.extraSpecialArgs = nixOSSpecialArgs;
            home-manager.backupFileExtension = "backup";
          }
        ] ++ (if onWSL then [ ] else
        ([
          inputs.xremap.nixosModules.default
          ./modules/nixos/system/login.nix
          ./modules/nixos/system/xremap.nix
          ./modules/nixos/system/dolphin.nix
        ]));
      in
      { } // (if requireStandalone then {
        homeConfigurations.${envUsername} = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
          extraSpecialArgs = {
            username = envUsername;
            homeDirectory = envHomeDir;
            onNixOS = false;
          };
        };
      } else {
        nixosConfigurations = {
          ${nixOSUserName} = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = nixOSModules;
            specialArgs = nixOSSpecialArgs // {
              envName = nixOSUserName;
            };
          };
          main = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = nixOSModules ++ [
              ./modules/nixos/system/nvidia.nix
              ./modules/nixos/system/steam.nix
            ];
            specialArgs = nixOSSpecialArgs // {
              envName = "main";
            };
          };
          mini = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = nixOSModules ++ [
              ./modules/nixos/system/steam.nix
            ];
            specialArgs = nixOSSpecialArgs // {
              envName = "mini";
            };
          };
          dyna = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = nixOSModules ++ [
              ./modules/nixos/system/dotnet.nix
            ];
            specialArgs = nixOSSpecialArgs // {
              envName = "dyna";
            };
          };
        };
      })
    );
}
