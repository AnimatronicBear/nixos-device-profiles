{ pkgs, lib, config, ... }: {
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  # https://github.com/systemd/systemd/pull/35304#issuecomment-3855146191
  # gnome autorotate expects 'normal' is the _display panel_ normal, but
  # mutter autoconfiguration rotates by 90deg.
  # compensating with gdctl for now, though it would be better to 'properly'
  # fix this.
  services.udev.extraHwdb = lib.mkIf config.hardware.sensor.iio.enable ''
    sensor:modalias:*sc7a20:*
      ACCEL_MOUNT_MATRIX=1, 0, 0; 0, 0, 1; 0, 1, 0
  '';
  environment.systemPackages = with pkgs; [
    gnomeExtensions.arc-menu
    gnomeExtensions.dash-to-dock
    gnomeExtensions.dash-to-panel
    gnomeExtensions.gjs-osk
    gnomeExtensions.one-window-wonderland
  ];
}
