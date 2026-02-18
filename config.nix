({ pkgs, lib, config, ... }:

let
  hostname = "PineTab2";
  username = "pinetab2";
  initialPassword = "changemee";
in
{
  # Ensure we don't try building zfs modules for the kernel (they're broken)
  nixpkgs.overlays = [
    (final: super: {
      zfs = super.zfs.overrideAttrs (_: {
        meta.platforms = [ ];
      });
    })
  ];
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "bes2600-firmware"
  ];

  system.stateVersion = "25.11";

  documentation.nixos.enable = false;

  nix.settings.trusted-users = [ username ];

  users.users.${username} = {
    inherit initialPassword;
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    uid = 1000;
  };

  boot.kernelParams = [ "console=ttyS2,1500000n8" "rootwait" "root=LABEL=NIXOS_SD" "rw" ];

  networking.networkmanager.enable = true;
  hardware.sensor.iio.enable = true;

  services = {
    openssh.enable = true;
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
    desktopManager.plasma6.enable = true;
    #displayManager.sddm = {
    #  enable = true;
    #  wayland.enable = true;
    #};

    automatic-timezoned.enable = true;
    geoclue2.enableDemoAgent = lib.mkForce true;

    flatpak.enable = true;
    printing.enable = true;

    avahi = {
      enable = true;
      openFirewall = true;
    };

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
    };
    pulseaudio.enable = false;
  };

  security.rtkit.enable = true;

  # https://github.com/systemd/systemd/pull/35304#issuecomment-3855146191
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
      echo $?
    '';
    serviceConfig.User = username;
    serviceConfig.Type = "oneshot";
    environment = {
      "DBUS_SESSION_BUS_ADDRESS" = "unix:path=/run/user/${toString config.users.users."${username}".uid}/bus";
    };
  };
  environment.systemPackages = with pkgs; [
    firefox
    chromium
    gnomeExtensions.arc-menu
    gnomeExtensions.dash-to-dock
    gnomeExtensions.dash-to-panel
    gnomeExtensions.gjs-osk
    gnomeExtensions.one-window-wonderland
    #kdePackages.qtvirtualkeyboard
    kdePackages.plasma-keyboard
    htop
    #xinput_calibrator
  ];

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  networking.hostName = "${hostname}";
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };
})
