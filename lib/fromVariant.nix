{
  lib,
  myLib,
  variantDir,
}:

let
  inherit (builtins) readDir;

  isVariantFile = name: type: type == "regular" && lib.hasSuffix ".nix" name;
  variantNames = lib.filterAttrs isVariantFile (readDir variantDir);

  # All imported variants keyed by name (filename minus .nix)
  variants = lib.mapAttrs' (name: _: {
    name = lib.removeSuffix ".nix" name;
    value = import (variantDir + "/${name}");
  }) variantNames;

  resolveProfiles = profiles: map (p: ../profiles/${p}/default.nix) (profiles);
  resolveDesktop = desktop: if desktop != null then ../hosts/common/optional/${desktop}.nix else { };
  resolveHost = host: ../hosts/nixos/${host};

  # Dispatch to the right NixOS builder based on variant definition.
  buildNixos =
    v: buildPlatform:
    let
      configName = v.configName or null;
    in
    let
      profilePaths = resolveProfiles (v.profiles or [ ]);
    in
    if v.platform == "rockchip" then
      if v.buildType == "installer" then
        myLib.rockchipInstallerConfigAarch64 buildPlatform (resolveHost v.host) profilePaths configName
      else
        myLib.rockchipOsConfigAarch64 buildPlatform (resolveHost v.host) (resolveDesktop
          v.desktop or null
        ) profilePaths configName
    else if v.platform == "generic" then
      if v.buildType == "installer" then
        myLib.installerConfigAarch64 buildPlatform (resolveHost v.host) profilePaths configName
      else
        myLib.osConfigAarch64 buildPlatform (resolveHost v.host) (resolveDesktop
          v.desktop or null
        ) profilePaths configName
    else if v.platform == "x86" then
      myLib.installerConfigX86 (resolveDesktop v.desktop or null) profilePaths configName
    else
      builtins.abort "fromVariant: unknown platform ${v.platform}";

  # Build a NixOS system to extract u-boot (no desktop module, no profiles).
  buildUboot =
    v: buildPlatform:
    let
      configName = v.configName or null;
    in
    if v.platform == "rockchip" then
      (myLib.rockchipOsConfigAarch64 buildPlatform (resolveHost v.host) { } [ ] configName)
      .config.rockchip.uBoot
    else
      builtins.abort "fromVariant: uboot only valid for rockchip platform";

  # Determine the buildPlatform for the top-level nixosConfiguration output.
  nixosBuildPlatform =
    v: system:
    if v.platform == "x86" then
      system
    else if v.cross or true then
      system
    else
      "aarch64-linux";

  # Build all outputs for a given system (buildPlatform for packages/checks).
  buildForSystem =
    system: pkgs:
    let
      # Generate check derivation from variant + evaluated config
      mkCheck =
        name: cfg: v:
        let
          assertEq =
            v: e: m:
            if v == e then
              ""
            else
              builtins.abort "${m}: expected ${builtins.toString e}, got ${builtins.toString v}";
          assertTrue =
            v: m: if v == true then "" else builtins.abort "${m}: expected true, got ${builtins.toString v}";
          assertFalse =
            v: m: if v == false then "" else builtins.abort "${m}: expected false, got ${builtins.toString v}";
          assertHasAttr =
            s: a: m:
            if builtins.hasAttr a s then "" else builtins.abort "${m}: expected attribute ${a}";
          assertNoAttr =
            s: a: m:
            if builtins.hasAttr a s then builtins.abort "${m}: unexpected attribute ${a}" else "";
          assertMatch =
            pattern: str: m:
            if builtins.match pattern str != null then "" else builtins.abort "${m}: pattern did not match";

          device = v.host;
          desktopName = v.desktop or null;
          accelKey = if v.buildType == "installer" then "gnome" else v.desktop or "gnome";
          hasProfiles = (v.profiles or [ ]) != [ ];

          accelMatrices = {
            gnome = "1, 0, 0; 0, 0, 1; 0, 1, 0";
            plasma = "0, 0, -1; -1, 0, 0; 0, 1, 0";
            phosh = "1, 0, 0; 0, 0, 1; 0, 1, 0";
          };
        in
        pkgs.runCommand "check-${name}" { } ''
              ${assertEq cfg.system.stateVersion "25.11" "stateVersion"}
              ${assertTrue cfg.services.pipewire.enable "pipewire"}
              ${assertEq (cfg.environment.sessionVariables.MOZ_ENABLE_WAYLAND or "") "1" "MOZ_ENABLE_WAYLAND"}
              ${assertFalse cfg.services.openssh.settings.PasswordAuthentication "PasswordAuthentication"}

              ${
                if device == "PineBookPro" || device == "PineTab2" || device == "X86Pc" then
                  let
                    hn = if device == "X86Pc" then "x86pc" else device;
                  in
                  assertEq cfg.networking.hostName hn "hostName"
                else
                  ""
              }

              ${
                if device == "PineTab2" then
                  assertTrue cfg.hardware.sensor.iio.enable "iio"
                else
                  assertFalse (cfg.hardware.sensor.iio.enable or false) "iio"
              }

              ${
                if desktopName == "gnome" then
                  ''
                    ${assertTrue cfg.services.desktopManager.gnome.enable "gnome"}
                    ${assertTrue cfg.services.displayManager.gdm.enable "gdm"}
                    ${
                      if device == "PineTab2" then
                        assertHasAttr (cfg.systemd.services or { }) "landscape" "landscape"
                      else
                        assertNoAttr (cfg.systemd.services or { }) "landscape" "landscape"
                    }
                  ''
                else if desktopName == "plasma" then
                  ''
                    ${assertTrue cfg.services.desktopManager.plasma6.enable "plasma6"}
                    ${assertTrue cfg.services.displayManager.sddm.enable "sddm"}
                    ${assertTrue cfg.services.displayManager.sddm.wayland.enable "sddm-wayland"}
                  ''
                else if desktopName == "phosh" then
                  ''
                    ${assertTrue cfg.services.xserver.desktopManager.phosh.enable "phosh"}
                    ${assertEq (cfg.services.xserver.desktopManager.phosh.phocConfig.xwayland or ""
                    ) "immediate" "xwayland"}
                    ${assertFalse cfg.security.pam.services.login.updateWtmp "updateWtmp"}
                  ''
                else
                  ""
              }

          ${
            if device == "PineTab2" then
              let
                expected = accelMatrices.${accelKey};
              in
              assertMatch ".*${expected}.*" (cfg.services.udev.extraHwdb or "") "ACCEL_MOUNT_MATRIX"
            else
              assertEq (cfg.services.udev.extraHwdb or "") "" "extraHwdb"
          }

          ${
            if v.checkProfiles or false then
              ''
                ${assertTrue (builtins.any (
                  p: lib.getName p == "gcc-wrapper"
                ) cfg.environment.systemPackages) "gcc"}
                ${assertTrue (builtins.any (p: lib.getName p == "git") cfg.environment.systemPackages) "git"}
              ''
            else
              ""
          }
              touch $out
        '';

      # Resolve package + config + check for each variant
      resolved = lib.mapAttrs (
        name: v:
        let
          bp = system;

          # nixosConfig — generated for deployable systems (not uboot, not x86)
          genNixosConfig = v.buildType != "uboot" && v.platform != "x86";
          nixosConfig = if genNixosConfig then buildNixos v (nixosBuildPlatform v system) else null;

          # Package — generated for variants with a buildable artifact
          package =
            if v.buildType == "uboot" then
              buildUboot v bp
            else if v.buildType == "none" then
              null
            else
              let
                cfg = buildNixos v bp;
              in
              if v.platform == "x86" then cfg.config.system.build.isoImage else cfg.config.system.build.sdImage;

          packageKey =
            if v.buildType == "none" then
              null
            else if v.buildType == "uboot" then
              name
            else
              "image-${name}";

          # Check — generated for all variants except uboot
          genCheck = v.buildType != "uboot";
          check =
            if genCheck then
              let
                cfg = buildNixos v bp;
              in
              mkCheck name cfg.config v
            else
              null;
        in
        {
          inherit
            package
            packageKey
            nixosConfig
            check
            ;
        }
      ) variants;
    in
    {
      nixosConfigurations = lib.mapAttrs (n: v: v.nixosConfig) (
        lib.filterAttrs (n: v: v.nixosConfig != null) resolved
      );
      packages = lib.listToAttrs (
        lib.flatten (
          lib.mapAttrsToList (
            n: v:
            if v.packageKey != null then
              [
                {
                  name = v.packageKey;
                  value = v.package;
                }
              ]
            else
              [ ]
          ) resolved
        )
      );
      checks = lib.mapAttrs (n: v: v.check) (lib.filterAttrs (n: v: v.check != null) resolved);
    };
in
{
  inherit buildForSystem;
}
