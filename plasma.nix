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
    # TODO this might still need explicit manual configuration on first install,
    # double-check
    kdePackages.plasma-keyboard
  ];
}
