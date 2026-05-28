{
  pkgs,
  lib,
  config,
  ...
}:
{
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  environment.systemPackages = with pkgs; [
    kdePackages.plasma-keyboard
  ];
}
