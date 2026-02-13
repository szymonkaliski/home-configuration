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

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-index-database,
      microvm,
      ...
    }:
    {
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      homeConfigurations = {
        "szymon@orchid" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;

          modules = [
            ./hosts/orchid/home.nix
            nix-index-database.homeModules.nix-index
          ];
        };

        "szymon@minix" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          modules = [
            ./hosts/minix/home.nix
            nix-index-database.homeModules.nix-index
            { nixpkgs.config.allowUnfree = true; }
          ];
        };
      };

      nixosConfigurations.minix = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit microvm; };

        modules = [
          ./hosts/minix/system.nix
          ./hosts/minix/hardware-configuration.nix
          ./hosts/minix/microvms
          microvm.nixosModules.host

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.users.szymon = {
              imports = [
                ./hosts/minix/home.nix
                nix-index-database.homeModules.nix-index
              ];
            };
          }
        ];
      };
    };
}
