{ lib, pkgs, config, rockchip, buildPlatform, ... }: {
  networking.hostName = "PineBookPro";
  rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootPinebookPro;
  boot.kernelPackages = rockchip.legacyPackages.${buildPlatform}.kernel_linux_latest_rockchip_stable;
  hardware.firmware = [ rockchip.packages.${buildPlatform}.brcm43456 ];
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "brcmfmac-firmware" ];
}
