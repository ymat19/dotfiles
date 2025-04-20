{
  description = "Home Manager configuration of ymat19";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xremap.url = "github:xremap/nix-flake";
  };

  outputs = { nixpkgs, home-manager, xremap, ... }:
    let
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
      nixOSUserName = "nixos";
      nixOSSpecialArgs = {
        username = nixOSUserName;
        homeDirectory = "/home/${nixOSUserName}";
        onWSL = onWSL;
        onNixOS = true;
      };
      nixOSModules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${nixOSUserName} = import ./home.nix;
          home-manager.extraSpecialArgs = nixOSSpecialArgs;
        }
      ] ++ (if onWSL then [ ] else [
        xremap.nixosModules.default
        ./modules/nixos/system/xremap.nix
        ./modules/nixos/system/login.nix
      ]);
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
        # not supported
        #parallels = nixpkgs.lib.nixosSystem {
        #  inherit system;
        #  modules = nixOSModules;
        #  specialArgs = nixOSSpecialArgs // {
        #    envName = "parallels";
        #  };
        #};
        main = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = nixOSModules;
          specialArgs = nixOSSpecialArgs // {
            envName = "main";
          };
        };
      };
    });
}
