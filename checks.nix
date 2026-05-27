{
  lib,
  pkgs,
  system,
  osConfigAarch64,
  installerConfigX86,
}:

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
    if builtins.match pattern str != null then
      ""
    else
      builtins.abort "${m}: pattern did not match '${pattern}'";

  mkCheck =
    device: deviceModule: desktopFile: desktopName:
    let
      cfg = (osConfigAarch64 system deviceModule desktopFile).config;
      hwdb = cfg.services.udev.extraHwdb or "";
      accelMatrices = {
        gnome = "1, 0, 0; 0, 0, 1; 0, 1, 0";
        plasma = "0, 0, -1; -1, 0, 0; 0, 1, 0";
        phosh = "1, 0, 0; 0, 0, 1; 0, 1, 0";
      };
    in
    pkgs.runCommand "check-${device}-${desktopName}" { } ''
      ${assertEq cfg.networking.hostName device "hostName"}
      ${assertEq cfg.system.stateVersion "25.11" "stateVersion"}
      ${assertTrue cfg.services.pipewire.enable "pipewire"}
      ${assertEq (cfg.environment.sessionVariables.MOZ_ENABLE_WAYLAND or "") "1" "MOZ_ENABLE_WAYLAND"}
      ${assertFalse cfg.services.openssh.settings.PasswordAuthentication "PasswordAuthentication"}

      ${
        if device == "PineBookPro" then
          assertFalse (cfg.hardware.sensor.iio.enable or false) "iio"
        else
          assertTrue cfg.hardware.sensor.iio.enable "iio"
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
        else
          ''
            ${assertTrue cfg.services.xserver.desktopManager.phosh.enable "phosh"}
            ${assertEq (cfg.services.xserver.desktopManager.phosh.phocConfig.xwayland or ""
            ) "immediate" "xwayland"}
            ${assertFalse cfg.security.pam.services.login.updateWtmp "updateWtmp"}
          ''
      }

      ${
        if device == "PineTab2" then
          let
            expected = accelMatrices.${desktopName};
          in
          assertMatch ".*${expected}.*" hwdb "ACCEL_MOUNT_MATRIX"
        else
          assertEq hwdb "" "extraHwdb"
      }
      touch $out
    '';
  mkCheckX86 =
    desktopFile: desktopName:
    let
      cfg = (installerConfigX86 desktopFile).config;
    in
    pkgs.runCommand "check-x86pc-${desktopName}" { } ''
      ${assertEq cfg.networking.hostName "x86pc" "hostName"}
      ${assertEq cfg.system.stateVersion "25.11" "stateVersion"}
      ${assertTrue cfg.services.pipewire.enable "pipewire"}
      ${assertEq (cfg.environment.sessionVariables.MOZ_ENABLE_WAYLAND or "") "1" "MOZ_ENABLE_WAYLAND"}
      ${assertFalse cfg.services.openssh.settings.PasswordAuthentication "PasswordAuthentication"}
      ${assertFalse (cfg.hardware.sensor.iio.enable or false) "iio"}
      ${assertNoAttr (cfg.systemd.services or { }) "landscape" "landscape"}
      ${assertEq (cfg.services.udev.extraHwdb or "") "" "extraHwdb"}

      ${
        if desktopName == "gnome" then
          ''
            ${assertTrue cfg.services.desktopManager.gnome.enable "gnome"}
            ${assertTrue cfg.services.displayManager.gdm.enable "gdm"}
          ''
        else if desktopName == "plasma" then
          ''
            ${assertTrue cfg.services.desktopManager.plasma6.enable "plasma6"}
            ${assertTrue cfg.services.displayManager.sddm.enable "sddm"}
            ${assertTrue cfg.services.displayManager.sddm.wayland.enable "sddm-wayland"}
          ''
        else
          ""
      }
      touch $out
    '';
in
{
  PineBookPro-gnome = mkCheck "PineBookPro" ./devices/pinebook-pro.nix ./gnome.nix "gnome";
  PineBookPro-plasma = mkCheck "PineBookPro" ./devices/pinebook-pro.nix ./plasma.nix "plasma";
  PineBookPro-phosh = mkCheck "PineBookPro" ./devices/pinebook-pro.nix ./phosh.nix "phosh";
  PineTab2-gnome = mkCheck "PineTab2" ./devices/pinetab2.nix ./gnome.nix "gnome";
  PineTab2-plasma = mkCheck "PineTab2" ./devices/pinetab2.nix ./plasma.nix "plasma";
  PineTab2-phosh = mkCheck "PineTab2" ./devices/pinetab2.nix ./phosh.nix "phosh";
  x86pc = mkCheckX86 { } "console";
  x86pc-gnome = mkCheckX86 ./gnome.nix "gnome";
  x86pc-plasma = mkCheckX86 ./plasma.nix "plasma";
}
