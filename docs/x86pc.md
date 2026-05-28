# x86_64 PC Installer

Standard NixOS ISO installer images for x86_64 PCs. Built natively (no
cross-compilation).

## User guide

[Build and flash from the project README](../README.md).

### Build

```shell
nix build .#image-installer-x86pc           # console-only
nix build .#image-installer-x86pc-gnome     # with GNOME desktop
nix build .#image-installer-x86pc-plasma    # with Plasma 6 desktop
```

### Flash to USB

```shell
dd if=result/iso-image/*.iso of=/dev/sdX bs=4M status=progress
```

### Boot from ISO

Standard UEFI boot. The ISO includes the default NixOS installer environment
(e.g. `nixos-install`, `parted`, `cryptsetup`). Desktop variants include
GNOME or Plasma 6 as the live environment.

## Kernel

Standard nixpkgs x86_64 kernel. No custom patches or firmware.

## Binary cache

Uses `cache.nixos.org` — x86_64 builds are fully cached by the official binary
cache.

## Quirks

- **Native build only** — no cross-compilation involved (x86_64 host → x86_64 target).
- **No Rockchip dependencies** — does not use the nabam nixos-rockchip module.
- **xdg-desktop-portal tests** — disabled via overlay in the device module
  (`doCheck = false`, `doInstallCheck = false`) because the integration tests
  require D-Bus/portal services not present in the nix build sandbox.
- **No IIO sensor** — desktop PCs don't have an accelerometer.
- **State version** 25.11, nixpkgs-unstable main channel.
- **SSH** is conditional — enabled only when `authorizedKey` is non-empty in `settings.nix`.

## Related projects

| Project | Role |
|---------|------|
| [NixOS ISO documentation](https://nixos.org/manual/nixos/stable/#sec-installation) | Official install guide |
| [NixOS ISO generation](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/cd-dvd/iso-image.nix) | ISO builder module |
