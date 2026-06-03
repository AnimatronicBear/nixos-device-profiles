{
  lib,
  config,
  modulesPath,
  ...
}:
{
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
