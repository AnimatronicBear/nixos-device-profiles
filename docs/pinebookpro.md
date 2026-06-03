# PineBookPro (RK3399)

PINE64 laptop with Rockchip RK3399 SoC.

## User guide

[Build and flash from the project README](../README.md).

### Build

```shell
nix build                     # GNOME (default)
nix build .#image-plasma      # Plasma 6
nix build .#image-phosh       # Phosh
nix build .#uboot             # u-boot only
nix build .#image-installer-pinebookpro
```

### Flash SD card

```shell
dd if=result/sd-image/* of=/dev/sdX bs=4M
```

### Flash u-boot to SD card

```shell
sudo dd if=$(readlink -f result)/u-boot-rockchip.bin of=/dev/sdX \
  conv=fsync,notrunc bs=16M seek=32768
```

(32768 = idbloaderOffset x 512 per
[nixos-rockchip sd-image-rockchip.nix](https://github.com/nabam/nixos-rockchip/blob/main/modules/sd-card/sd-image-rockchip.nix).)

### Flash u-boot to SPI flash

```shell
scp result/u-boot-rockchip-spi.bin user@host:
ssh user@host
nix-shell -p mtdutils
flashcp -v -A u-boot-rockchip-spi.bin /dev/mtd0
```

SPI flash is not available via Docker compose — run nix natively on the device.

### Remote update

```shell
nixos-rebuild --flake .#PineBookPro switch \
  --target-host user@host \
  --use-remote-sudo --ask-sudo-password
```

## Kernel

Rockchip stable kernel from nabam/nixos-rockchip (`kernel_linux_latest_rockchip_stable`).
Includes `brcmfmac-firmware` for the Broadcom 43456 WiFi/BT module.

## Binary cache

`nabam-nixos-rockchip.cachix.org` configured in the device module for kernel, u-boot,
and firmware. Cross-compiled from x86_64.

## Quirks

- **No IIO sensor** — the RK3399 lacks a hardware rotation sensor.
- **SPI flash** (PineBookPro only) stores u-boot; only the SD card copy is updated by
  `nix build .#uboot`. SPI flash requires native nix on device.
- **Console** on `ttyS2` at 1500000 baud.
- **State version** 25.11, nixpkgs-unstable main channel.
- **SSH** is conditional — enabled only when `authorizedKey` is non-empty in `settings.nix`.

## Related projects

| Project | Role |
|---------|------|
| [nabam/nixos-rockchip](https://github.com/nabam/nixos-rockchip) | Rockchip SD image builder, u-boot packages, kernels |
| [raboof/pinetab2-nixos](https://codeberg.org/raboof/pinetab2-nixos) | Original fork source (PineTab2-only) |
| [PINE64 PineBookPro wiki](https://wiki.pine64.org/wiki/PineBook_Pro) | Hardware docs, schematics |
| [NixOS on ARM](https://nixos.wiki/wiki/NixOS_on_ARM) | General ARM + NixOS guides |
