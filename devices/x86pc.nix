{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/cd-dvd/iso-image.nix" ];

  # xdg-desktop-portal 1.20.4 integration tests dynamiclauncher and
  # notification/sound_fd fail in the build sandbox (need D-Bus session,
  # desktop portal services). Disable tests on native x86_64 builds.
  # ARM cross-compilation already skips tests automatically.
  nixpkgs.overlays = [
    (final: prev: {
      xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (_: {
        doCheck = false;
        doInstallCheck = false;
      });
    })
  ];
}
