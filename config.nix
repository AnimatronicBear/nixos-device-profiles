({ pkgs, lib, config, ... }:

let
  hostname = "PineTab2";
  username = "pinetab2";
  initialPassword = "changeme";
in
{
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

  services.openssh.enable = true;

  services.automatic-timezoned.enable = true;
  services.geoclue2.enableDemoAgent = lib.mkForce true;

  #services.flatpak.enable = true;
  services.printing.enable = true;

  services.avahi = {
    enable = true;
    openFirewall = true;
  };

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    jack.enable = true;
  };
  services.pulseaudio.enable = false;

  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    firefox
    chromium
    htop
  ];

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  networking.hostName = "${hostname}";
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };
})
