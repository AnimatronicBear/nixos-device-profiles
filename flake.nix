{
  inputs = {
    nixpkgsStable.url = "nixpkgs/nixos-25.11";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    rockchip = {
      #url = "github:nabam/nixos-rockchip";
      url = "github:raboof/nixos-rockchip/pinetab2-kernel-6.18.10";
      inputs.utils.follows = "utils";
      inputs.nixpkgsStable.follows = "nixpkgsStable";
      inputs.nixpkgsUnstable.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rockchip, utils, ... }:
  let
    osConfig =
      buildPlatform:
      nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";

        modules = [
          rockchip.nixosModules.sdImageRockchip
          rockchip.nixosModules.dtOverlayPCIeFix
          ./config.nix
          {
            # Use cross-compilation for uBoot and Kernel.
            rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootPineTab2;
            boot.kernelPackages =
              rockchip.legacyPackages.${buildPlatform}.kernel_linux_6_18_pinetab_stable;
            hardware.firmware = [ rockchip.packages.aarch64-linux.bes2600 ];
          }
        ];
      };
  in
  {
    nixosConfigurations.PineTab2 = osConfig "x86_64-linux";
  } // utils.lib.eachDefaultSystem (system: {
    packages.image = (osConfig system).config.system.build.sdImage;
    packages.default = self.packages.${system}.image;
  });
}
