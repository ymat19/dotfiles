{
  description = "Home Manager configuration of ymat19";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = builtins.currentSystem;
      pkgs = nixpkgs.legacyPackages.${system};
      envUsername = builtins.getEnv "USER";
      envHomeDir  = builtins.getEnv "HOME";
      hostName = "nixos";
    in {
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${envUsername} = import ./home.nix {
                inherit pkgs;
                username = envUsername;
                homeDirectory = envHomeDir;
              };
            }
            ({ config, pkgs, ... }: {
              networking.hostName = hostName;
            })
          ];
        };

      homeConfigurations.${envUsername} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ ./home.nix ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
        extraSpecialArgs = {
          username = envUsername;
          homeDirectory = envHomeDir;
        };
      };
    };
}
