{ pkgs, lib, config, ... }: {
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  environment.systemPackages = with pkgs; [
    gnomeExtensions.arc-menu
    gnomeExtensions.dash-to-dock
    gnomeExtensions.dash-to-panel
    gnomeExtensions.gjs-osk
    gnomeExtensions.one-window-wonderland
  ];
}
