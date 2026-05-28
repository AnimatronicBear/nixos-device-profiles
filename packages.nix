{
  lib,
  pkgs,
  system,
  rockchipOsConfigAarch64,
  rockchipInstallerConfigAarch64,
  osConfigAarch64,
  installerConfigAarch64,
  installerConfigX86,
}:

let
  image-gnome =
    (rockchipOsConfigAarch64 system ./devices/pinebook-pro.nix ./gnome.nix).config.system.build.sdImage;
  image-plasma =
    (rockchipOsConfigAarch64 system ./devices/pinebook-pro.nix ./plasma.nix)
    .config.system.build.sdImage;
  image-pinetab2-gnome =
    (rockchipOsConfigAarch64 system ./devices/pinetab2.nix ./gnome.nix).config.system.build.sdImage;
  image-pinetab2-plasma =
    (rockchipOsConfigAarch64 system ./devices/pinetab2.nix ./plasma.nix).config.system.build.sdImage;
  uboot = (rockchipOsConfigAarch64 system ./devices/pinebook-pro.nix { }).config.rockchip.uBoot;
  uboot-pinetab2 = (rockchipOsConfigAarch64 system ./devices/pinetab2.nix { }).config.rockchip.uBoot;
  image-installer-pinebookpro =
    (rockchipInstallerConfigAarch64 system ./devices/pinebook-pro.nix).config.system.build.sdImage;
  image-installer-pinetab2 =
    (rockchipInstallerConfigAarch64 system ./devices/pinetab2.nix).config.system.build.sdImage;
  image-generic-aarch64 =
    (osConfigAarch64 system ./devices/generic-aarch64.nix ./gnome.nix).config.system.build.sdImage;
  image-installer-generic-aarch64 =
    (installerConfigAarch64 system ./devices/generic-aarch64.nix).config.system.build.sdImage;
  image-installer-x86pc = (installerConfigX86 { }).config.system.build.isoImage;
  image-installer-x86pc-gnome = (installerConfigX86 ./gnome.nix).config.system.build.isoImage;
  image-installer-x86pc-plasma = (installerConfigX86 ./plasma.nix).config.system.build.isoImage;
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
