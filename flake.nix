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
      envSudoUsername = builtins.getEnv "SUDO_USER";
      envHomeDir = builtins.getEnv "HOME";
      hostName = "nixos";
      requireStandalone = !builtins.pathExists "/etc/nixos";
    in
    { } // (if requireStandalone then {
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
    } else {
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${envSudoUsername} = import ./home.nix;
            home-manager.extraSpecialArgs = {
              username = envSudoUsername;
              homeDirectory = "/home/${envSudoUsername}";
            };
          }
        ];
      };
    });
}
