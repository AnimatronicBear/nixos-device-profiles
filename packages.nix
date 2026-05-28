{
  lib,
  pkgs,
  system,
  myLib,
}:

let
  image-gnome =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineBookPro ./hosts/common/optional/gnome.nix)
    .config.system.build.sdImage;
  image-plasma =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineBookPro ./hosts/common/optional/plasma.nix)
    .config.system.build.sdImage;
  image-pinetab2-gnome =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineTab2 ./hosts/common/optional/gnome.nix)
    .config.system.build.sdImage;
  image-pinetab2-plasma =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineTab2 ./hosts/common/optional/plasma.nix)
    .config.system.build.sdImage;
  uboot = (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineBookPro { }).config.rockchip.uBoot;
  uboot-pinetab2 =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineTab2 { }).config.rockchip.uBoot;
  image-installer-pinebookpro =
    (myLib.rockchipInstallerConfigAarch64 system ./hosts/nixos/PineBookPro).config.system.build.sdImage;
  image-installer-pinetab2 =
    (myLib.rockchipInstallerConfigAarch64 system ./hosts/nixos/PineTab2).config.system.build.sdImage;
  image-generic-aarch64 =
    (myLib.osConfigAarch64 system ./hosts/nixos/GenericAarch64 ./hosts/common/optional/gnome.nix)
    .config.system.build.sdImage;
  image-installer-generic-aarch64 =
    (myLib.installerConfigAarch64 system ./hosts/nixos/GenericAarch64).config.system.build.sdImage;
  image-installer-x86pc = (myLib.installerConfigX86 { }).config.system.build.isoImage;
  image-installer-x86pc-gnome =
    (myLib.installerConfigX86 ./hosts/common/optional/gnome.nix).config.system.build.isoImage;
  image-installer-x86pc-plasma =
    (myLib.installerConfigX86 ./hosts/common/optional/plasma.nix).config.system.build.isoImage;
in
{
  inherit
    image-gnome
    image-plasma
    image-pinetab2-gnome
    image-pinetab2-plasma
    uboot
    uboot-pinetab2
    image-installer-pinebookpro
    image-installer-pinetab2
    image-generic-aarch64
    image-installer-generic-aarch64
    image-installer-x86pc
    image-installer-x86pc-gnome
    image-installer-x86pc-plasma
    ;
  default = image-gnome;
}
