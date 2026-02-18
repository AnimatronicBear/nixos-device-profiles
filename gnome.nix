{ pkgs, lib, config, ... }:

let
  username = "pinetab2";
in
{
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  # https://github.com/systemd/systemd/pull/35304#issuecomment-3855146191
  # gnome autorotate expects 'normal' is the _display panel_ normal, but
  # mutter autoconfiguration rotates by 90deg.
  # compensating with gdctl for now, though it would be better to 'properly'
  # fix this.
  services.udev = {
    extraHwdb = ''
      sensor:modalias:*sc7a20:*
        ACCEL_MOUNT_MATRIX=1, 0, 0; 0, 0, 1; 0, 1, 0
    '';
    extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1018", ATTRS{idProduct}=="1006", ENV{SYSTEMD_WANTS}+="landscape.service", TAG+="systemd"
    '';
  };
  systemd.services.landscape = {
    script = ''
      ${pkgs.mutter}/bin/gdctl set --logical-monitor --primary --monitor=DSI-1 --transform normal
    '';
    serviceConfig.User = username;
    serviceConfig.Type = "oneshot";
    environment = {
      "DBUS_SESSION_BUS_ADDRESS" = "unix:path=/run/user/${toString config.users.users."${username}".uid}/bus";
    };
  };
  environment.systemPackages = with pkgs; [
    gnomeExtensions.arc-menu
    gnomeExtensions.dash-to-dock
    gnomeExtensions.dash-to-panel
    gnomeExtensions.gjs-osk
    gnomeExtensions.one-window-wonderland
  ];
}
