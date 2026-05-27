{
  inputs = {
    nixpkgsStable.url = "nixpkgs/nixos-25.11";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rockchip = {
      url = "github:nabam/nixos-rockchip";
      inputs.utils.follows = "utils";
      inputs.nixpkgsStable.follows = "nixpkgsStable";
      inputs.nixpkgsUnstable.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rockchip,
      utils,
      home-manager,
      ...
    }:

    let
      settingsFile =
        if builtins.pathExists ./settings.nix then ./settings.nix else ./settings.nix.example;
      settings = import settingsFile;
      overlayModule =
        { config, lib, ... }:
        {
          nixpkgs.overlays = import ./overlays;
        };

      osConfigAarch64 =
        buildPlatform: deviceModule: variant:
        nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit rockchip buildPlatform settings; };
          modules = [
            overlayModule
            { nixpkgs.hostPlatform = "aarch64-linux"; }
            { nixpkgs.buildPlatform = buildPlatform; }
            rockchip.nixosModules.sdImageRockchip
            home-manager.nixosModules.home-manager
            ./config.nix
            variant
            deviceModule
          ];
        };

      installerConfigAarch64 =
        buildPlatform: deviceModule:
        nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit rockchip buildPlatform settings; };
          modules = [
            overlayModule
            { nixpkgs.hostPlatform = "aarch64-linux"; }
            { nixpkgs.buildPlatform = buildPlatform; }
            rockchip.nixosModules.sdImageRockchipInstaller
            home-manager.nixosModules.home-manager
            ./config.nix
            deviceModule
          ];
        };

      installerConfigX86 =
        variant:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit settings; };
          modules = [
            overlayModule
            { nixpkgs.hostPlatform = "x86_64-linux"; }
            home-manager.nixosModules.home-manager
            ./config.nix
            ./devices/x86pc.nix
            variant
          ];
        };
    in
    {
      nixConfig = {
        max-jobs = 4;
        cores = 0;
        extra-substituters = [ "https://nabam-nixos-rockchip.cachix.org" ];
        extra-trusted-public-keys = [
          "nabam-nixos-rockchip.cachix.org-1:BQDltcnV8GS/G86tdvjLwLFz1WeFqSk7O9yl+DR0AVM"
        ];
      };

      nixosConfigurations.PineBookPro =
        osConfigAarch64 "x86_64-linux" ./devices/pinebook-pro.nix
          ./gnome.nix;
      nixosConfigurations.PineBookPro-plasma =
        osConfigAarch64 "x86_64-linux" ./devices/pinebook-pro.nix
          ./plasma.nix;
      nixosConfigurations.PineBookPro-phosh =
        osConfigAarch64 "x86_64-linux" ./devices/pinebook-pro.nix
          ./phosh.nix;
      nixosConfigurations.PineTab2 = osConfigAarch64 "x86_64-linux" ./devices/pinetab2.nix ./gnome.nix;
      nixosConfigurations.PineTab2-plasma =
        osConfigAarch64 "x86_64-linux" ./devices/pinetab2.nix
          ./plasma.nix;
      nixosConfigurations.PineTab2-phosh =
        osConfigAarch64 "x86_64-linux" ./devices/pinetab2.nix
          ./phosh.nix;
    }
    // utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;
        checks = import ./checks.nix {
          inherit
            lib
            pkgs
            system
            osConfigAarch64
            installerConfigX86
            ;
        };
        myPackages = import ./packages.nix {
          inherit
            lib
            pkgs
            system
            osConfigAarch64
            installerConfigAarch64
            installerConfigX86
            ;
        };
      in
      {
        packages = myPackages;
        formatter = pkgs.nixfmt-tree;
        checks = checks;
      }
    );
}
