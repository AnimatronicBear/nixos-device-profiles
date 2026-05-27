{
  lib,
  pkgs,
  config,
  rockchip,
  buildPlatform,
  ...
}:
{
  imports = [ rockchip.nixosModules.noZFS ];
  networking.hostName = "PineBookPro";
  rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootPinebookPro;
  boot.kernelPackages = rockchip.legacyPackages.${buildPlatform}.kernel_linux_latest_rockchip_stable;
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS2,1500000n8"
    "rootwait"
    "root=LABEL=NIXOS_SD"
    "rw"
  ];
  hardware.firmware = [ rockchip.packages.${buildPlatform}.brcm43456 ];
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "brcmfmac-firmware" ];
  nix.settings = {
    extra-substituters = [ "https://nabam-nixos-rockchip.cachix.org" ];
    extra-trusted-public-keys = [
      "nabam-nixos-rockchip.cachix.org-1:BQDltcnV8GS/G86tdvjLwLFz1WeFqSk7O9yl+DR0AVM"
    ];
  };
}
