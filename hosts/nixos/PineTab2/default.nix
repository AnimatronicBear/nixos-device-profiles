{
  lib,
  pkgs,
  config,
  rockchip,
  buildPlatform,
  settings,
  ...
}:
{
  imports = [
    rockchip.nixosModules.dtOverlayPCIeFix
    rockchip.nixosModules.noZFS
  ];
  networking.hostName = "PineTab2";
  rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootPineTab2;
  boot.kernelPackages = rockchip.legacyPackages.${buildPlatform}.kernel_linux_6_18_pinetab_stable;
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS2,1500000n8"
    "rootwait"
    "root=LABEL=NIXOS_SD"
    "rw"
  ];
  hardware.firmware = [ rockchip.packages.${buildPlatform}.bes2600 ];
  nixpkgs.config.allowUnfree = true;
  hardware.sensor.iio.enable = true;
  networking.networkmanager.wifi.powersave = false;

  services.udev.extraHwdb = ''
    sensor:modalias:*sc7a20:*
      ACCEL_MOUNT_MATRIX=${
        if config.services.desktopManager.gnome.enable then
          "1, 0, 0; 0, 0, 1; 0, 1, 0"
        else if config.services.desktopManager.plasma6.enable then
          "0, 0, -1; -1, 0, 0; 0, 1, 0"
        else
          "1, 0, 0; 0, 0, 1; 0, 1, 0"
      }
  '';

  services.udev.extraRules = lib.mkIf config.services.desktopManager.gnome.enable ''
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1018", ATTRS{idProduct}=="1006", ENV{SYSTEMD_WANTS}+="landscape.service", TAG+="systemd"
  '';
  nix.settings = {
    extra-substituters = [ "https://nabam-nixos-rockchip.cachix.org" ];
    extra-trusted-public-keys = [
      "nabam-nixos-rockchip.cachix.org-1:BQDltcnV8GS/G86tdvjLwLFz1WeFqSk7O9yl+DR0AVM"
    ];
  };

  systemd.services.landscape = lib.mkIf config.services.desktopManager.gnome.enable {
    script = ''
      ${pkgs.mutter}/bin/gdctl set --logical-monitor --primary --monitor=DSI-1 --transform normal
    '';
    serviceConfig.User = settings.username;
    serviceConfig.Type = "oneshot";
    environment = {
      "DBUS_SESSION_BUS_ADDRESS" = "unix:path=/run/user/${
        toString config.users.users."${settings.username}".uid
      }/bus";
    };
  };
}
