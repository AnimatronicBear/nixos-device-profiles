{
  inputs = {
    nixpkgsStable.url = "nixpkgs/nixos-25.11";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    rockchip = {
      url = "github:nabam/nixos-rockchip";
      inputs.utils.follows = "utils";
      inputs.nixpkgsStable.follows = "nixpkgsStable";
      inputs.nixpkgsUnstable.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rockchip, utils, ... }:

  let
    osConfig = buildPlatform: deviceModule: variant:
      nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit rockchip buildPlatform; };
        modules = [
          { nixpkgs.hostPlatform = "aarch64-linux"; }
          { nixpkgs.buildPlatform = buildPlatform; }
          rockchip.nixosModules.sdImageRockchip
          rockchip.nixosModules.noZFS
          ./config.nix
          variant
          deviceModule
        ];
      };
  in
  {
    nixosConfigurations.PineBookPro = osConfig "x86_64-linux" ./devices/pinebook-pro.nix ./gnome.nix;
    nixosConfigurations.PineBookPro-plasma = osConfig "x86_64-linux" ./devices/pinebook-pro.nix ./plasma.nix;
    nixosConfigurations.PineBookPro-phosh = osConfig "x86_64-linux" ./devices/pinebook-pro.nix ./phosh.nix;
    nixosConfigurations.PineTab2 = osConfig "x86_64-linux" ./devices/pinetab2.nix ./gnome.nix;
    nixosConfigurations.PineTab2-plasma = osConfig "x86_64-linux" ./devices/pinetab2.nix ./plasma.nix;
    nixosConfigurations.PineTab2-phosh = osConfig "x86_64-linux" ./devices/pinetab2.nix ./phosh.nix;
  } // utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    lib = nixpkgs.lib;

    assertEq = v: e: m: if v == e then "" else builtins.abort "${m}: expected ${builtins.toString e}, got ${builtins.toString v}";
    assertTrue = v: m: if v == true then "" else builtins.abort "${m}: expected true, got ${builtins.toString v}";
    assertFalse = v: m: if v == false then "" else builtins.abort "${m}: expected false, got ${builtins.toString v}";
    assertHasAttr = s: a: m: if builtins.hasAttr a s then "" else builtins.abort "${m}: expected attribute ${a}";
    assertNoAttr = s: a: m: if builtins.hasAttr a s then builtins.abort "${m}: unexpected attribute ${a}" else "";
    assertMatch = pattern: str: m: if builtins.match pattern str != null then "" else builtins.abort "${m}: pattern did not match '${pattern}'";

    mkCheck = device: deviceModule: desktopFile: desktopName: let
      cfg = (osConfig system deviceModule desktopFile).config;
      hwdb = cfg.services.udev.extraHwdb or "";
      accelMatrices = {
        gnome = "1, 0, 0; 0, 0, 1; 0, 1, 0";
        plasma = "0, 0, -1; -1, 0, 0; 0, 1, 0";
        phosh = "1, 0, 0; 0, 0, 1; 0, 1, 0";
      };
    in pkgs.runCommand "check-${device}-${desktopName}" { } ''
      ${assertEq cfg.networking.hostName device "hostName"}
      ${assertEq cfg.system.stateVersion "25.11" "stateVersion"}
      ${assertTrue cfg.services.pipewire.enable "pipewire"}
      ${assertEq (cfg.environment.sessionVariables.MOZ_ENABLE_WAYLAND or "") "1" "MOZ_ENABLE_WAYLAND"}
      ${assertFalse cfg.services.openssh.settings.PasswordAuthentication "PasswordAuthentication"}

      ${if device == "PineBookPro" then
        assertFalse (cfg.hardware.sensor.iio.enable or false) "iio"
      else
        assertTrue cfg.hardware.sensor.iio.enable "iio"
      }

      ${if desktopName == "gnome" then ''
        ${assertTrue cfg.services.desktopManager.gnome.enable "gnome"}
        ${assertTrue cfg.services.displayManager.gdm.enable "gdm"}
        ${if device == "PineTab2" then
          assertHasAttr (cfg.systemd.services or {}) "landscape" "landscape"
        else
          assertNoAttr (cfg.systemd.services or {}) "landscape" "landscape"
        }
      '' else if desktopName == "plasma" then ''
        ${assertTrue cfg.services.desktopManager.plasma6.enable "plasma6"}
        ${assertTrue cfg.services.displayManager.sddm.enable "sddm"}
        ${assertTrue cfg.services.displayManager.sddm.wayland.enable "sddm-wayland"}
      '' else ''
        ${assertTrue cfg.services.xserver.desktopManager.phosh.enable "phosh"}
        ${assertEq (cfg.services.xserver.desktopManager.phosh.phocConfig.xwayland or "") "immediate" "xwayland"}
        ${assertFalse cfg.security.pam.services.login.updateWtmp "updateWtmp"}
      ''}

      ${if device == "PineTab2" then
        let expected = accelMatrices.${desktopName};
        in assertMatch ".*${expected}.*" hwdb "ACCEL_MOUNT_MATRIX"
      else
        assertEq hwdb "" "extraHwdb"
      }
      touch $out
    '';
  in {
    packages.image-gnome = (osConfig system ./devices/pinebook-pro.nix ./gnome.nix).config.system.build.sdImage;
    packages.image-plasma = (osConfig system ./devices/pinebook-pro.nix ./plasma.nix).config.system.build.sdImage;
    packages.image-pinetab2-gnome = (osConfig system ./devices/pinetab2.nix ./gnome.nix).config.system.build.sdImage;
    packages.image-pinetab2-plasma = (osConfig system ./devices/pinetab2.nix ./plasma.nix).config.system.build.sdImage;
    packages.uboot = (osConfig system ./devices/pinebook-pro.nix { }).config.rockchip.uBoot;
    packages.uboot-pinetab2 = (osConfig system ./devices/pinetab2.nix { }).config.rockchip.uBoot;
    packages.default = self.packages.${system}.image-gnome;

    checks = {
      PineBookPro-gnome = mkCheck "PineBookPro" ./devices/pinebook-pro.nix ./gnome.nix "gnome";
      PineBookPro-plasma = mkCheck "PineBookPro" ./devices/pinebook-pro.nix ./plasma.nix "plasma";
      PineBookPro-phosh = mkCheck "PineBookPro" ./devices/pinebook-pro.nix ./phosh.nix "phosh";
      PineTab2-gnome = mkCheck "PineTab2" ./devices/pinetab2.nix ./gnome.nix "gnome";
      PineTab2-plasma = mkCheck "PineTab2" ./devices/pinetab2.nix ./plasma.nix "plasma";
      PineTab2-phosh = mkCheck "PineTab2" ./devices/pinetab2.nix ./phosh.nix "phosh";
    };
  });
}
