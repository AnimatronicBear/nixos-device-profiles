{
  pkgs,
  lib,
  config,
  settings,
  ...
}:
{
  # phosh is actually wayland, should move this option
  # https://github.com/NixOS/nixpkgs/issues/499593
  services.xserver.desktopManager.phosh = {
    enable = true;
    group = "users";
    user = settings.username;
    phocConfig.xwayland = "immediate";
  };

  security.pam.services.login = {
    updateWtmp = lib.mkForce false;
  };

  environment.systemPackages = with pkgs; [
  ];
}
