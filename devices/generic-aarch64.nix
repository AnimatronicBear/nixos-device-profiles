{
  lib,
  config,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.kernelParams = [
    "console=tty0"
    "rootwait"
    "root=LABEL=NIXOS_SD"
    "rw"
  ];

  sdImage = {
    populateFirmwareCommands = "";
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };
}
