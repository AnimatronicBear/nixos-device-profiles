{
  lib,
  config,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "usb_storage"
    "usbhid"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/mapper/luks-a110e6c3-37e2-4baa-8301-97aab321d7dc";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/73CE-06DC";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    { device = "/dev/mapper/luks-127bfa81-becb-487f-8ada-53e44c5b375a"; }
  ];

  boot.initrd.luks.devices."luks-a110e6c3-37e2-4baa-8301-97aab321d7dc".device =
    "/dev/disk/by-uuid/a110e6c3-37e2-4baa-8301-97aab321d7dc";

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-127bfa81-becb-487f-8ada-53e44c5b375a" = {
    device = "/dev/disk/by-uuid/127bfa81-becb-487f-8ada-53e44c5b375a";
    crypttabExtraOpts = [ "fido2-device=auto" ];
  };

  boot.kernelParams = [
    "console=tty1"
    "rootwait"
    "root=LABEL=NIXOS_ROOT"
    "rw"
  ];

  nix.settings = {
    extra-substituters = [
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
}
