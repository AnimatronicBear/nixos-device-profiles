({ pkgs, lib, config, ... }:

let
  secrets = import ./secrets.nix;
  username = secrets.username;
in
{
  system.stateVersion = "25.11";

  zramSwap.enable = true;

  # CVE-2026-31431 (Copy Fail) mitigation — algif_aead allows local
  # privilege escalation on kernels 4.14–6.19.12. Blacklist the module
  # until the kernel can be updated with the upstream fix.
  boot.blacklistedKernelModules = [ "algif_aead" ];

  documentation.nixos.enable = false;

  nix.settings.trusted-users = [ username ];

  users.users.${username} = {
    initialPassword = secrets.initialPassword;
    openssh.authorizedKeys.keys = [ secrets.authorizedKey ];
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    uid = 1000;
  };

  boot.kernelParams = [ "console=tty0" "console=ttyS2,1500000n8" "rootwait" "root=LABEL=NIXOS_SD" "rw" ];

  networking.networkmanager = {
    enable = true;
    # bes2600 powersave causes wifi stability issues, dmesg:
    # bes2600_wlan mmc2:0001:1: bes2600_pwr_enter_lp_mode, wait pm ind timeout
    # wifi.powersave = false;
    ensureProfiles.profiles."${secrets.ssid}" = {
      connection = {
        id = secrets.ssid;
        interface-name = "wlan0";
        type = "wifi";
        uuid = "f5541fe5-a769-4c72-b106-d87d1432792e";
      };
      ipv4 = {
        method = "auto";
      };
      ipv6 = {
        addr-gen-mode = "default";
        method = "auto";
      };
      proxy = { };
      wifi = {
        mode = "infrastructure";
        ssid = secrets.ssid;
      };
      wifi-security = {
        auth-alg = "open";
        key-mgmt = "wpa-psk";
        psk = secrets.psk;
      };
   };
  };

  services.openssh = {
    enable = builtins.stringLength secrets.authorizedKey > 0;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

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

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    git
    htop
  ];

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  nix.settings = {
    auto-optimise-store = true;
    max-jobs = 4;
    cores = 0;
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://nabam-nixos-rockchip.cachix.org" ];
    extra-trusted-public-keys = [
      "nabam-nixos-rockchip.cachix.org-1:BQDltcnV8GS/G86tdvjLwLFz1WeFqSk7O9yl+DR0AVM"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username} = import ./home.nix;
  };
})
