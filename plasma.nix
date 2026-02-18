{ pkgs, lib, config, ... }:

{
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  # https://github.com/systemd/systemd/pull/35304#issuecomment-3855146191
  # plasma expects 'normal' is the _device_ normal
  services.udev = {
    extraHwdb = ''
      sensor:modalias:*sc7a20:*
        ACCEL_MOUNT_MATRIX=0, 0, -1; -1, 0, 0; 0, 1, 0
    '';
  };
  environment.systemPackages = with pkgs; [
    # TODO this might still need explicit manual configuration on first install,
    # double-check
    kdePackages.plasma-keyboard
  ];
}
