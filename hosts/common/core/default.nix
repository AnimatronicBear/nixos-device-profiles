(
  {
    pkgs,
    lib,
    config,
    settings,
    ...
  }:
  {
    system.stateVersion = settings.stateVersion;

    networking.hostName = lib.mkDefault settings.hostName;

    zramSwap.enable = true;

    # CVE-2026-31431 (Copy Fail) mitigation — algif_aead allows local
    # privilege escalation on kernels 4.14–6.19.12. Blacklist the module
    # until the kernel can be updated with the upstream fix.
    boot.blacklistedKernelModules = [ "algif_aead" ];

    documentation.nixos.enable = false;

    nix.settings.trusted-users = [ settings.username ];

    users.users.${settings.username} = {
      initialPassword = settings.initialPassword;
      openssh.authorizedKeys.keys = [ settings.authorizedKey ];
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "docker"
      ];
      uid = 1000;
    };

    security.sudo.extraRules = [
      {
        users = [ settings.username ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    networking.networkmanager = {
      enable = true;
      ensureProfiles.profiles."${settings.ssid}" = {
        connection = {
          id = settings.ssid;
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
          ssid = settings.ssid;
        };
        wifi-security = {
          auth-alg = "open";
          key-mgmt = "wpa-psk";
          psk = settings.psk;
        };
      };
    };

    services.openssh = {
      enable = builtins.stringLength settings.authorizedKey > 0;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };

    services.automatic-timezoned.enable = true;
    services.geoclue2.enableDemoAgent = lib.mkForce true;

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

    environment.systemPackages = builtins.map (name: pkgs.${name}) settings.extraSystemPackages;

    environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };

    nix.settings = {
      auto-optimise-store = true;
      max-jobs = 4;
      cores = 0;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inherit settings; };
      users.${settings.username} = import ../../../home/_username_/common/core/default.nix;
    };
  }
)
