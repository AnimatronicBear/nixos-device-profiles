# Generic AArch64 SBC

Any aarch64 SBC that boots via generic extlinux (no Rockchip-specific boot
requirements). Example boards: Raspberry Pi 3/4/5 (with vendor U-Boot),
Qualcomm devices, Allwinner boards, etc.

This profile uses the standard NixOS SD image infrastructure
(`installer/sd-card/sd-image.nix`) with extlinux-compatible bootloader.

## User guide

[Build and flash from the project README](../README.md).

### Build

```shell
nix build .#image-generic-aarch64              # GNOME desktop
nix build .#image-installer-generic-aarch64    # installer (no desktop)
```

### Flash SD card

```shell
dd if=result/sd-image/* of=/dev/sdX bs=4M
```

### Remote update

```shell
nixos-rebuild --flake .#GenericAarch64 switch \
  --target-host user@host \
  --use-remote-sudo --ask-sudo-password
```

## Kernel

Standard nixpkgs aarch64 kernel (no custom patches). The SD image does not include
device-specific firmware — ensure your board has proper firmware loaded by U-Boot
or the boot ROM.

## Binary cache

Both `cache.nixos.org` and `nabam-nixos-rockchip.cachix.org` are configured.
The nabam cache may provide some cross-compiled aarch64 packages for shared
dependencies.

## Boot

```nix
boot.loader.grub.enable = false;
boot.loader.generic-extlinux-compatible.enable = true;
```

Uses extlinux bootloader (`/boot/extlinux/extlinux.conf`). The `populateRootCommands`
copies the extlinux config into the boot partition. No custom firmware or first-stage
bootloader is included — the board's existing U-Boot must support extlinux.

## Quirks

- **No IIO sensor** — the profile does not enable any hardware sensor.
- **No landscape service** — no udev rules for keyboard docks.
- **No PCIe overlay** — the generic module does not apply the RK3566 PCIe fix.
- **Console** on `tty0` only (no serial console configured).
- **State version** 25.11, nixpkgs-unstable main channel.
- **SSH** is conditional — enabled only when `authorizedKey` is non-empty in `settings.nix`.

## Related projects

| Project | Role |
|---------|------|
| [NixOS on ARM](https://nixos.wiki/wiki/NixOS_on_ARM) | Generic ARM SD image docs, board-specific guides |
| [nixos-generators](https://github.com/nix-community/nixos-generators) | Alternative image formats for ARM SBCs |
| [mainline U-Boot](https://docs.u-boot.org/en/latest/board/index.html) | Board-specific U-Boot builds if extlinux not supported |
