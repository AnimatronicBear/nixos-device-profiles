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

  outputs = { self, nixpkgs, rockchip, utils, home-manager, ... }:

  let
    secretsFile = if builtins.pathExists ./secrets.nix then ./secrets.nix else ./secrets.nix.example;
    settings = import secretsFile;
    overlayModule = { config, lib, ... }: {
      nixpkgs.overlays = import ./overlays;
    };

    checks = import ./checks.nix { inherit lib pkgs system osConfig; };

    osConfig = buildPlatform: deviceModule: variant:
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

    installerConfig = buildPlatform: deviceModule:
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

    nixosConfigurations.PineBookPro = osConfig "x86_64-linux" ./devices/pinebook-pro.nix ./gnome.nix;
    nixosConfigurations.PineBookPro-plasma = osConfig "x86_64-linux" ./devices/pinebook-pro.nix ./plasma.nix;
    nixosConfigurations.PineBookPro-phosh = osConfig "x86_64-linux" ./devices/pinebook-pro.nix ./phosh.nix;
    nixosConfigurations.PineTab2 = osConfig "x86_64-linux" ./devices/pinetab2.nix ./gnome.nix;
    nixosConfigurations.PineTab2-plasma = osConfig "x86_64-linux" ./devices/pinetab2.nix ./plasma.nix;
    nixosConfigurations.PineTab2-phosh = osConfig "x86_64-linux" ./devices/pinetab2.nix ./phosh.nix;
  } // utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    lib = nixpkgs.lib;
  in {
    packages.image-gnome = (osConfig system ./devices/pinebook-pro.nix ./gnome.nix).config.system.build.sdImage;
    packages.image-plasma = (osConfig system ./devices/pinebook-pro.nix ./plasma.nix).config.system.build.sdImage;
    packages.image-pinetab2-gnome = (osConfig system ./devices/pinetab2.nix ./gnome.nix).config.system.build.sdImage;
    packages.image-pinetab2-plasma = (osConfig system ./devices/pinetab2.nix ./plasma.nix).config.system.build.sdImage;
    packages.uboot = (osConfig system ./devices/pinebook-pro.nix { }).config.rockchip.uBoot;
    packages.uboot-pinetab2 = (osConfig system ./devices/pinetab2.nix { }).config.rockchip.uBoot;
    packages.image-installer-pinebookpro = (installerConfig system ./devices/pinebook-pro.nix).config.system.build.sdImage;
    packages.image-installer-pinetab2 = (installerConfig system ./devices/pinetab2.nix).config.system.build.sdImage;
    packages.default = self.packages.${system}.image-gnome;

    formatter = pkgs.nixfmt-tree;

    checks = checks;
  });
}
