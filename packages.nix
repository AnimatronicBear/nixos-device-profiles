{
  lib,
  pkgs,
  system,
  myLib,
}:

let
  image-gnome =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineBookPro ./hosts/common/optional/gnome.nix
      [ ]
      null
    ).config.system.build.sdImage;
  image-plasma =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineBookPro ./hosts/common/optional/plasma.nix
      [ ]
      null
    ).config.system.build.sdImage;
  image-pinetab2-gnome =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineTab2 ./hosts/common/optional/gnome.nix [ ]
      null
    ).config.system.build.sdImage;
  image-pinetab2-plasma =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineTab2 ./hosts/common/optional/plasma.nix [ ]
      null
    ).config.system.build.sdImage;
  uboot =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineBookPro { } [ ] null).config.rockchip.uBoot;
  uboot-pinetab2 =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineTab2 { } [ ] null).config.rockchip.uBoot;
  image-pinetab2-phosh =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineTab2 ./hosts/common/optional/phosh.nix [ ]
      null
    ).config.system.build.sdImage;
  image-phosh =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineBookPro ./hosts/common/optional/phosh.nix
      [ ]
      null
    ).config.system.build.sdImage;
  image-installer-pinebookpro =
    (myLib.rockchipInstallerConfigAarch64 system ./hosts/nixos/PineBookPro [ ] null)
    .config.system.build.sdImage;
  image-installer-pinetab2 =
    (myLib.rockchipInstallerConfigAarch64 system ./hosts/nixos/PineTab2 [ ] null)
    .config.system.build.sdImage;
  image-generic-aarch64 =
    (myLib.osConfigAarch64 system ./hosts/nixos/GenericAarch64 ./hosts/common/optional/gnome.nix [ ]
      null
    ).config.system.build.sdImage;
  image-generic-aarch64-botany-bay =
    (myLib.osConfigAarch64 system ./hosts/nixos/GenericAarch64 ./hosts/common/optional/gnome.nix [
      ./profiles/botany-bay/default.nix
    ] null
    ).config.system.build.sdImage;
  image-installer-generic-aarch64 =
    (myLib.installerConfigAarch64 system ./hosts/nixos/GenericAarch64 [ ] null)
    .config.system.build.sdImage;
  image-dev =
    (myLib.rockchipOsConfigAarch64 system ./hosts/nixos/PineBookPro ./hosts/common/optional/gnome.nix [
      ./profiles/base/default.nix
      ./profiles/development/default.nix
    ] null).config.system.build.sdImage;
  image-installer-x86pc = (myLib.installerConfigX86 { } [ ] null).config.system.build.isoImage;
  image-installer-x86pc-gnome =
    (myLib.installerConfigX86 ./hosts/common/optional/gnome.nix [ ] null).config.system.build.isoImage;
  image-installer-x86pc-plasma =
    (myLib.installerConfigX86 ./hosts/common/optional/plasma.nix [ ] null).config.system.build.isoImage;
in
{
  inherit
    image-gnome
    image-plasma
    image-pinetab2-gnome
    image-pinetab2-plasma
    image-pinetab2-phosh
    image-phosh
    uboot
    uboot-pinetab2
    image-installer-pinebookpro
    image-installer-pinetab2
    image-generic-aarch64
    image-installer-generic-aarch64
    image-dev
    image-installer-x86pc
    image-installer-x86pc-gnome
    image-installer-x86pc-plasma
    ;
  default = image-gnome;
}
