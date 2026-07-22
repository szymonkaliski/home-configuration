{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      nix-index-database,
      microvm,
      sops-nix,
      ...
    }:
    let
      # antigravity is not in nixos-26.05, pull from unstable;
      # separate pkgs instance, so it needs its own allowUnfree
      antigravityOverlay = final: prev: {
        antigravity-cli =
          (import nixpkgs-unstable {
            inherit (prev.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          }).antigravity-cli;
      };
    in
    {
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      homeConfigurations = {
        "szymon@orchid" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "aarch64-darwin";
            overlays = [
              (final: prev: {
                # skipping tests, as fish ones are flaky on darwin:
                # https://github.com/NixOS/nixpkgs/issues/475999
                direnv = prev.direnv.overrideAttrs { doCheck = false; };
              })
              antigravityOverlay
            ];
          };
          extraSpecialArgs = {
            repoRoot = "/Users/szymon/Documents/Projects/home-configuration";
          };

          modules = [
            ./hosts/orchid/home.nix
            nix-index-database.homeModules.nix-index
            sops-nix.homeManagerModules.sops
            { nixpkgs.config.allowUnfree = true; }
          ];
        };

        "szymon@minix" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [ antigravityOverlay ];
          };
          extraSpecialArgs = {
            repoRoot = "/home/szymon/Projects/home-configuration";
          };

          modules = [
            ./hosts/minix/home.nix
            nix-index-database.homeModules.nix-index
            sops-nix.homeManagerModules.sops
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
          sops-nix.nixosModules.sops
        ];
      };
    };
}
