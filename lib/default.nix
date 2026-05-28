{
  nixpkgs,
  rockchip,
  home-manager,
  utils,
  settings,
}:

let
  overlayModule =
    { config, lib, ... }:
    {
      nixpkgs.overlays = import ../overlays;
    };

in
{
  rockchipOsConfigAarch64 =
    buildPlatform: hostModule: variant:
    nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit rockchip buildPlatform settings; };
      modules = [
        overlayModule
        { nixpkgs.hostPlatform = "aarch64-linux"; }
        { nixpkgs.buildPlatform = buildPlatform; }
        rockchip.nixosModules.sdImageRockchip
        home-manager.nixosModules.home-manager
        ../hosts/common/core/default.nix
        variant
        hostModule
      ];
    };

  rockchipInstallerConfigAarch64 =
    buildPlatform: hostModule:
    nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit rockchip buildPlatform settings; };
      modules = [
        overlayModule
        { nixpkgs.hostPlatform = "aarch64-linux"; }
        { nixpkgs.buildPlatform = buildPlatform; }
        rockchip.nixosModules.sdImageRockchipInstaller
        home-manager.nixosModules.home-manager
        ../hosts/common/core/default.nix
        hostModule
      ];
    };

  osConfigAarch64 =
    buildPlatform: hostModule: variant:
    nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit buildPlatform settings; };
      modules = [
        overlayModule
        { nixpkgs.hostPlatform = "aarch64-linux"; }
        { nixpkgs.buildPlatform = buildPlatform; }
        home-manager.nixosModules.home-manager
        ../hosts/common/core/default.nix
        variant
        hostModule
      ];
    };

  installerConfigAarch64 =
    buildPlatform: hostModule:
    nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit buildPlatform settings; };
      modules = [
        overlayModule
        { nixpkgs.hostPlatform = "aarch64-linux"; }
        { nixpkgs.buildPlatform = buildPlatform; }
        home-manager.nixosModules.home-manager
        ../hosts/common/core/default.nix
        hostModule
      ];
    };

  installerConfigX86 =
    variant:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit settings; };
      modules = [
        { nixpkgs.hostPlatform = "x86_64-linux"; }
        home-manager.nixosModules.home-manager
        ../hosts/common/core/default.nix
        ../hosts/nixos/X86Pc/default.nix
        variant
      ];
    };
}
