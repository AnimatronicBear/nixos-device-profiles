# PineTab2 (RK3566)

PINE64 tablet with Rockchip RK3566 SoC.

## User guide

[Build and flash from the project README](../README.md).

### Build

```shell
nix build .#image-pinetab2-gnome     # GNOME
nix build .#image-pinetab2-plasma    # Plasma 6
nix build .#image-pinetab2-phosh     # Phosh
nix build .#uboot-pinetab2           # u-boot only
nix build .#image-installer-pinetab2 # installer (no desktop)
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

### Remote update

```shell
nixos-rebuild --flake .#PineTab2 switch \
  --target-host user@host \
  --use-remote-sudo --ask-sudo-password
```

## Kernel

DanctNIX kernel (`kernel_linux_6_18_pinetab_stable`), maintained upstream at
[DanctNIX/linux-pinetab2](https://github.com/DanctNIX/linux-pinetab2).

## Binary cache

`nabam-nixos-rockchip.cachix.org` configured in the device module. Cross-compiled
from x86_64.

## Quirks

- **IIO sensor** (`sc7a20`) — accelerometer is enabled; rotation is handled per-desktop
  via `ACCEL_MOUNT_MATRIX` in `services.udev.extraHwdb`.
- **GNOME rotation** — a `landscape.service` oneshot runs `gdctl set` on USB keyboard
  dock attach to switch the display to landscape. Triggered by udev rule matching
  the PINE64 keyboard dock (USB vendor 1018, product 1006).
- **Accel mount matrices** by desktop:
  - GNOME / Phosh: `1, 0, 0; 0, 0, 1; 0, 1, 0`
  - Plasma: `0, 0, -1; -1, 0, 0; 0, 1, 0`
- **WiFi stability** — `bes2600` powersave is disabled (`networking.networkmanager.wifi.powersave = false`)
  to avoid kernel timeout: `bes2600_pwr_enter_lp_mode, wait pm ind timeout`.
- **PCIe fix** — the `dtOverlayPCIeFix` module is applied for the RK3566 PCIe
  controller quirk.
- **CVE-2026-31431 (Copy Fail)** — the DanctNIX 6.18.10 kernel is before the upstream
  fix. Mitigated by blacklisting `algif_aead` in the shared core module.
- **Console** on `ttyS2` at 1500000 baud.
- **State version** 25.11, nixpkgs-unstable main channel.
- **SSH** is conditional — enabled only when `authorizedKey` is non-empty in `settings.nix`.

## Related projects

| Project | Role |
|---------|------|
| [DanctNIX/linux-pinetab2](https://github.com/DanctNIX/linux-pinetab2) | Custom kernel for PineTab2 |
| [nabam/nixos-rockchip](https://github.com/nabam/nixos-rockchip) | Rockchip SD image builder, u-boot packages, fix modules |
| [raboof/pinetab2-nixos](https://codeberg.org/raboof/pinetab2-nixos) | Original fork source (PineTab2-only) |
| [PINE64 PineTab2 wiki](https://wiki.pine64.org/wiki/PineTab2) | Hardware docs, keyboard dock pinout |
| [NixOS on ARM](https://nixos.wiki/wiki/NixOS_on_ARM) | General ARM + NixOS guides |
