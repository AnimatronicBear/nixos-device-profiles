{ lib, pkgs, config, rockchip, buildPlatform, ... }:

let
  username = (import ../secrets.nix).username;
in {
  networking.hostName = "PineTab2";
  rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootPineTab2;
  boot.kernelPackages = rockchip.legacyPackages.${buildPlatform}.kernel_linux_6_18_pinetab_stable;
  hardware.firmware = [ rockchip.packages.${buildPlatform}.bes2600 ];
  nixpkgs.config.allowUnfree = true;
  hardware.sensor.iio.enable = true;
  networking.networkmanager.wifi.powersave = false;

  # Keyboard dock orientation correction (GNOME-specific)
  services.udev.extraRules = lib.mkIf config.services.desktopManager.gnome.enable ''
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1018", ATTRS{idProduct}=="1006", ENV{SYSTEMD_WANTS}+="landscape.service", TAG+="systemd"
  '';
  systemd.services.landscape = lib.mkIf config.services.desktopManager.gnome.enable {
    script = ''
      ${pkgs.mutter}/bin/gdctl set --logical-monitor --primary --monitor=DSI-1 --transform normal
    '';
    serviceConfig.User = username;
    serviceConfig.Type = "oneshot";
    environment = {
      "DBUS_SESSION_BUS_ADDRESS" = "unix:path=/run/user/${toString config.users.users."${username}".uid}/bus";
    };
  };
}
