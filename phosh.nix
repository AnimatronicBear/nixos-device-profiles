{ pkgs, lib, config, ... }:

let
  username = (import ./secrets.nix).username;
in
{
  # phosh is actually wayland, should move this option
  # https://github.com/NixOS/nixpkgs/issues/499593
  services.xserver.desktopManager.phosh = {
    enable = true;
    group = "users";
    user = username;
    phocConfig.xwayland = "immediate";
  };

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
  };

  # otherwise 
  # Mar 13 18:41:09 PineTab2 (phosh-session)[1135]: PAM unable to dlopen(/nix/store/751j4vwz7vbljv4h8d6rhw2dbwilkjk3-util-linux-2.41.3-lastlog/lib/security/pam_lastlog2.so): /nix/store/751j4vwz7vbljv4h8d6rhw2dbwilkjk3-util-linux-2.41.3-lastlog/lib/security/pam_lastlog2.so: undefined symbol: pam_syslog
  security.pam.services.login = {
    updateWtmp = lib.mkForce false;
  };

  environment.systemPackages = with pkgs; [
  ];
}
