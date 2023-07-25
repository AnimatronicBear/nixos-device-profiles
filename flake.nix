{
  inputs = {
    nixpkgsStable.url = "nixpkgs/nixos-23.05";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    rockchip.url = "github:asonix/nixos-rockchip/asonix/pinetab2-linux-6.4.3";
  };

  outputs = { self, nixpkgs, rockchip, ... }:
  let
    system = "aarch64-linux";
    hostname = "PineTab2";
    username = "pinetab2";
    initialPassword = "changeme";

    pkgs = import nixpkgs {
      inherit system;
    };

    buildNixosConfiguration = { kernel, uBoot }: nixpkgs.lib.nixosSystem {
      inherit system;

      modules = [
        rockchip.nixosModules.sdImageRockchip
        rockchip.nixosModules.dtOverlayPCIeFix

        # pinetab2 cachix
        {
          nix = {
            settings = {
              substituters = [
                "https://pinetab2.cachix.org"
              ];
              trusted-public-keys = [
                "pinetab2.cachix.org-1:q3+zliGsfh1MH76ugM2GkPQcO2nALvM3sDSS/dXnxcE="
              ];
            };
          };
        }

        ({ pkgs, lib, ... }: {
          # Ensure we don't try building zfs modules for the kernel (they're broken)
          nixpkgs.overlays = [
            (final: super: {
              zfs = super.zfs.overrideAttrs (_: {
                meta.platforms = [ ];
              });
            })
          ];

          system.stateVersion = "23.11";

          users.users.${username} = {
            inherit initialPassword;
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" ];
          };

          rockchip.uBoot = (rockchip.uBoot system).uBootPineTab2;

          boot.kernelPackages = kernel;
          boot.kernelParams = [ "console=ttyS2,1500000n8" "rootwait" "root=LABEL=NIXOS_SD" "rw" ];

          networking.networkmanager.enable = true;

          services = {
            xserver = {
              enable = true;
              desktopManager.gnome.enable = true;
              displayManager.gdm.enable = true;
            };

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
          };

          sound.enable = true;
          hardware.pulseaudio.enable = false;
          security.rtkit.enable = true;

          environment.systemPackages = with pkgs; [
            cachix
            firefox
            gnomeExtensions.arc-menu
            gnomeExtensions.dash-to-dock
            gnomeExtensions.dash-to-panel
            gnomeExtensions.gjs-osk
            gnomeExtensions.one-window-wonderland
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
      ];
    };
  in
  {
    nixosConfigurations.${hostname} = buildNixosConfiguration {
      # use a custom kernel for next rebuild (we have cachix now)
      kernel = (rockchip.kernel system).linux_6_4_pinetab;
      # kernel = pkgs.linuxPackages_latest;
      # todo: uboot isn't required after we're already booting
      uBoot = (rockchip.uBoot system).uBootPineTab2;
    };
    nixosConfigurations.nixos = buildNixosConfiguration {
      # use a prebuilt kernel for first rebuild
      kernel = pkgs.linuxPackages_latest;
      # todo: uboot isn't required after we're already booting
      uBoot = (rockchip.uBoot system).uBootPineTab2;
    };
  };
}
