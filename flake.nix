{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    utils.url = "github:numtide/flake-utils";
    rockchip = {
      url = "github:nabam/nixos-rockchip";
      inputs.utils.follows = "utils";
      inputs.nixpkgsStable.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rockchip, utils, ... }:
  let
    system = "aarch64-linux";
    hostname = "PineTab2";
    username = "pinetab2";
    initialPassword = "changeme";

    pkgs = import nixpkgs {
      inherit system;
    };

    osConfig =
      buildPlatform:
      nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          rockchip.nixosModules.sdImageRockchip
          rockchip.nixosModules.dtOverlayPCIeFix
          ({ pkgs, lib, ... }: {
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

            system.stateVersion = "25.05";

            documentation.nixos.enable = false;

            nix.settings.trusted-users = [ username ];

            users.users.${username} = {
              inherit initialPassword;
              isNormalUser = true;
              extraGroups = [ "wheel" "networkmanager" ];
            };

            boot.kernelParams = [ "console=ttyS2,1500000n8" "rootwait" "root=LABEL=NIXOS_SD" "rw" ];

            networking.networkmanager.enable = true;
            hardware.sensor.iio.enable = true;

            services = {
              openssh.enable = true;
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

            hardware.pulseaudio.enable = false;
            security.rtkit.enable = true;

            environment.systemPackages = with pkgs; [
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
            hardware.firmware = [ rockchip.packages.${system}.bes2600 ];
          })
          {
            # Use cross-compilation for uBoot and Kernel.
            rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootPineTab2;
            boot.kernelPackages =
              rockchip.legacyPackages.${buildPlatform}.kernel_linux_6_18_pinetab_stable;
          }
        ];
      };
  in
  {
    nixosConfigurations.${hostname} = osConfig "x86_64-linux";
  } // utils.lib.eachDefaultSystem (system: {
    packages.image = (osConfig system).config.system.build.sdImage;
    packages.default = self.packages.${system}.image;
  });
}
