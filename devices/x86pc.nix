{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/cd-dvd/iso-image.nix" ];
  # Add x86pc-specific hardware config here when needed:
  # - boot.loader.grub.device (for BIOS/UEFI)
  # - hardware.enableRedistributableFirmware
  # - services.fwupd.enable
  # - services.thermald.enable
}
