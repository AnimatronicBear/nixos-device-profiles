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

  # otherwise
  # Mar 13 18:41:09 PineBookPro (phosh-session)[1135]: PAM unable to dlopen(/nix/store/751j4vwz7vbljv4h8d6rhw2dbwilkjk3-util-linux-2.41.3-lastlog/lib/security/pam_lastlog2.so): /nix/store/751j4vwz7vbljv4h8d6rhw2dbwilkjk3-util-linux-2.41.3-lastlog/lib/security/pam_lastlog2.so: undefined symbol: pam_syslog
  security.pam.services.login = {
    updateWtmp = lib.mkForce false;
  };

  environment.systemPackages = with pkgs; [
  ];
}
