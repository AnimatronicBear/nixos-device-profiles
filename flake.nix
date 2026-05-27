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
            rockchip.nixosModules.noZFS
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
            rockchip.nixosModules.noZFS
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
            (
              { modulesPath, ... }:
              {
                imports = [ "${modulesPath}/installer/cd-dvd/iso-image.nix" ];
              }
            )
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
      in
      {
        packages.image-gnome =
          (osConfigAarch64 system ./devices/pinebook-pro.nix ./gnome.nix).config.system.build.sdImage;
        packages.image-plasma =
          (osConfigAarch64 system ./devices/pinebook-pro.nix ./plasma.nix).config.system.build.sdImage;
        packages.image-pinetab2-gnome =
          (osConfigAarch64 system ./devices/pinetab2.nix ./gnome.nix).config.system.build.sdImage;
        packages.image-pinetab2-plasma =
          (osConfigAarch64 system ./devices/pinetab2.nix ./plasma.nix).config.system.build.sdImage;
        packages.uboot = (osConfigAarch64 system ./devices/pinebook-pro.nix { }).config.rockchip.uBoot;
        packages.uboot-pinetab2 = (osConfigAarch64 system ./devices/pinetab2.nix { }).config.rockchip.uBoot;
        packages.image-installer-pinebookpro =
          (installerConfigAarch64 system ./devices/pinebook-pro.nix).config.system.build.sdImage;
        packages.image-installer-pinetab2 =
          (installerConfigAarch64 system ./devices/pinetab2.nix).config.system.build.sdImage;
        packages.image-installer-x86pc = (installerConfigX86 { }).config.system.build.isoImage;
        packages.image-installer-x86pc-gnome =
          (installerConfigX86 ./gnome.nix).config.system.build.isoImage;
        packages.image-installer-x86pc-plasma =
          (installerConfigX86 ./plasma.nix).config.system.build.isoImage;
        packages.default = self.packages.${system}.image-gnome;

        formatter = pkgs.nixfmt-tree;

        checks = checks;
      }
    );
}
