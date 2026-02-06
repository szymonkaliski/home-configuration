{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-index-database,
      ...
    }:
    {
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      homeConfigurations = {
        "szymon@orchid" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;

          modules = [
            ./orchid/home.nix
            nix-index-database.homeModules.nix-index
          ];
        };
      };

      nixosConfigurations.minix = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./minix/system.nix
          ./minix/hardware-configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.szymon = {
              imports = [
                ./minix/home.nix
                nix-index-database.homeModules.nix-index
              ];
            };
          }
        ];
      };
    };
}
