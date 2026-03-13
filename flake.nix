{
  inputs = {
    nixpkgsStable.url = "nixpkgs/nixos-25.11";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    rockchip = {
      url = "github:raboof/nixos-rockchip/pinetab-unstable-kernel-6.19";
      #url = "github:nabam/nixos-rockchip";
      inputs.utils.follows = "utils";
      inputs.nixpkgsStable.follows = "nixpkgsStable";
      inputs.nixpkgsUnstable.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rockchip, utils, ... }:
  let
    osConfig =
      buildPlatform:
      variant:
      nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";

        modules = [
          rockchip.nixosModules.sdImageRockchip
          rockchip.nixosModules.dtOverlayPCIeFix
          rockchip.nixosModules.noZFS
          ./config.nix
          variant
          {
            # Use cross-compilation for uBoot and Kernel.
            rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootPineTab2;
            boot.kernelPackages =
              rockchip.legacyPackages.${buildPlatform}.kernel_linux_6_19_pinetab_unstable;

            hardware.firmware = [ rockchip.packages.aarch64-linux.bes2600 ];
            nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
              "bes2600-firmware"
            ];
          }
        ];
      };
  in
  {
    nixosConfigurations.PineTab2 = osConfig "x86_64-linux" ./gnome.nix;
    nixosConfigurations.PineTab2-plasma = osConfig "x86_64-linux" ./plasma.nix;
    nixosConfigurations.PineTab2-phosh = osConfig "x86_64-linux" ./phosh.nix;
  } // utils.lib.eachDefaultSystem (system: {
    packages.image-gnome = (osConfig system ./gnome.nix).config.system.build.sdImage;
    packages.image-plasma = (osConfig system ./plasma.nix).config.system.build.sdImage;
    packages.uboot = (osConfig system {}).config.rockchip.uBoot;
    packages.default = self.packages.${system}.image-gnome;
  });
}
