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

    # `main` pins nixos-25.11 while `develop` tracks 26.05
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/develop";
  };

  nixConfig = {
    extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      nix-index-database,
      microvm,
      sops-nix,
      nixos-raspberrypi,
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

      # home-manager re-imports nixpkgs from the module-level nixpkgs.* options,
      # so overlays and allowUnfree are set there, not on a pkgs instance
      mkHome =
        {
          system,
          host,
          repoRoot,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit repoRoot; };
          modules = [
            ./nix/hosts/${host}/home.nix
            nix-index-database.homeModules.nix-index
            sops-nix.homeModules.sops
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = [ antigravityOverlay ];
            }
          ];
        };

      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # written to an sd card for Raspberry Pi
      packages.aarch64-linux.berry-sd-image = self.nixosConfigurations.berry.config.system.build.sdImage;

      homeConfigurations = {
        "szymon@orchid" = mkHome {
          system = "aarch64-darwin";
          host = "orchid";
          repoRoot = "/Users/szymon/.config/home-manager";
        };

        "szymon@minix" = mkHome {
          system = "x86_64-linux";
          host = "minix";
          repoRoot = "/home/szymon/.config/home-manager";
        };

        "szymon@berry" = mkHome {
          system = "aarch64-linux";
          host = "berry";
          repoRoot = "/home/szymon/.config/home-manager";
        };
      };

      # nixos-raspberrypi's own nixosSystem, so the vendor kernel and firmware
      # resolve against the nixpkgs their cachix was built with
      nixosConfigurations.berry = nixos-raspberrypi.lib.nixosSystem {
        modules = [
          {
            imports = with nixos-raspberrypi.nixosModules; [
              raspberry-pi-5.base
              sd-image
            ];
          }
          ./nix/hosts/berry/system.nix
          sops-nix.nixosModules.sops
        ];
      };

      nixosConfigurations.minix = nixpkgs.lib.nixosSystem {
        modules = [
          { nixpkgs.overlays = [ antigravityOverlay ]; }
          ./nix/hosts/minix/system.nix
          ./nix/hosts/minix/hardware-configuration.nix
          ./nix/hosts/minix/microvms
          microvm.nixosModules.host
          sops-nix.nixosModules.sops
        ];
      };
    };
}
