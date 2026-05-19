# NixOS for Pine64 Devices

NixOS flake for **PineBookPro** (RK3399 laptop) and **PineTab2** (RK3566 tablet).
Cross-compiled from x86_64 → aarch64-linux.

Forked from [raboof/pinetab2-nixos](https://codeberg.org/raboof/pinetab2-nixos)
which originally targeted PineTab2 only. This fork adds PineBookPro support,
multi-device architecture, and home-manager integration.

## Supported configurations

| Device | Desktop | Flake attr | Accel matrix |
|--------|---------|------------|--------------|
| PineBookPro | GNOME (default) | `.#PineBookPro` / `.#image-gnome` | (none — no sensor) |
| PineBookPro | Plasma 6 | `.#PineBookPro-plasma` / `.#image-plasma` | (none — no sensor) |
| PineBookPro | Phosh | `.#PineBookPro-phosh` | (none — no sensor) |
| PineTab2 | GNOME | `.#PineTab2` / `.#image-pinetab2-gnome` | `1,0,0; 0,0,1; 0,1,0` |
| PineTab2 | Plasma 6 | `.#PineTab2-plasma` / `.#image-pinetab2-plasma` | `0,0,-1; -1,0,0; 0,1,0` |
| PineTab2 | Phosh | `.#PineTab2-phosh` | `1,0,0; 0,0,1; 0,1,0` |

## Before building

### 1. `secrets.nix` (gitignored)

Copy `secrets.nix.example` to `secrets.nix` and edit — set `initialPassword`,
`authorizedKey`, `ssid`, `psk`.

### 2. `settings.nix` (tracked)

Edit `settings.nix` to set your `username`, `gitUserName`, `gitUserEmail`,
and package preferences.

## Building an SD card image

```shell
# PineBookPro GNOME (default)
nix build

# PineBookPro Plasma
nix build .#image-plasma

# PineTab2 GNOME
nix build .#image-pinetab2-gnome

# PineTab2 Plasma
nix build .#image-pinetab2-plasma
```

Installer images (no desktop, for recovery/installation):

```shell
nix build .#image-installer-pinebookpro
nix build .#image-installer-pinetab2
```

Flash the result:

```shell
dd if=result/sd-image/* of=/dev/sdX bs=4M
```

## Updating a running system

```shell
nixos-rebuild --flake .#PineBookPro switch \
  --target-host user@host \
  --use-remote-sudo --ask-sudo-password
```

Substitute `PineTab2` for the tablet variant.

## Installing to eMMC

Boot from SD and dd the image onto the internal storage:

```shell
dd if=/dev/zero of=/dev/mmcblk0 bs=1M count=16
dd if=result/sd-image/*.img of=/dev/mmcblk0 bs=4M conv=fsync
```

## Updating u-boot

The bootloader is not updated by `nixos-rebuild`. To update it, plug the SD
card into your dev machine:

```shell
nix build .#uboot           # PineBookPro
nix build .#uboot-pinetab2  # PineTab2
```

Then write u-boot to the SD card:

```shell
sudo dd if=$(readlink -f result)/u-boot-rockchip.bin of=/dev/sdX \
  conv=fsync,notrunc bs=16M seek=32768
```

(32768 = idbloaderOffset × 512, as defined in
[nixos-rockchip](https://github.com/nabam/nixos-rockchip/blob/main/modules/sd-card/sd-image-rockchip.nix).)

To flash u-boot to the device's SPI flash (PineBookPro only):

```shell
scp result/u-boot-rockchip-spi.bin user@host:
ssh user@host
nix-shell -p mtdutils
flashcp -v -A u-boot-rockchip-spi.bin /dev/mtd0
```

## Key packages

| Package | Where | Notes |
|---------|-------|-------|
| `git`, `htop` | System (`settings.nix` → `config.nix`) | `extraSystemPackages` |
| `docker` | System (`config.nix`) | User in `docker` group |
| `librewolf`, `ungoogled-chromium`, `vscodium` | User (`settings.nix` → `home.nix`) | `extraUserPackages` |

System packages and user packages are configured in `settings.nix`. User
dotfiles (git config, VSCodium extensions, browser settings) are managed by
[home-manager](https://github.com/nix-community/home-manager) in `home.nix`.

## Binary cache

The flake uses `nabam-nixos-rockchip.cachix.org` for pre-built kernels,
u-boot, and firmware (configured at both the flake and NixOS system level).

## Security

**CVE-2026-31431 (Copy Fail)** is mitigated by blacklisting `algif_aead`
in `config.nix`. The nixpkgs stable input is updated to a kernel containing
the upstream fix (available for PineBookPro; PineTab2 uses a custom DanctNIX
kernel that relies on the blacklist workaround).

## Docker compose

Run nix build and checks inside a container without a host nix-daemon:

```shell
docker compose run check
docker compose run build
docker compose run dev    # interactive shell
```

A named Docker volume (`nix-store`) is used for `/nix`, preserving the
container's built-in nix binary while caching store paths across runs
(needs root Docker).

## Checks

```shell
nix flake check    # eval-only, no kernel compilation

# Individual checks:
nix build .#checks.x86_64-linux.PineBookPro-gnome
nix build .#checks.x86_64-linux.PineTab2-plasma
```

## Code formatting

```shell
nix fmt    # uses nixfmt-tree
```

## Quick reference

| Action | Command |
|--------|---------|
| Build image (PBP GNOME) | `nix build` |
| Build image (PT2 GNOME) | `nix build .#image-pinetab2-gnome` |
| Build installer (PBP) | `nix build .#image-installer-pinebookpro` |
| Build installer (PT2) | `nix build .#image-installer-pinetab2` |
| Build u-boot (PBP) | `nix build .#uboot` |
| Build u-boot (PT2) | `nix build .#uboot-pinetab2` |
| Docker check | `docker compose run check` |
| Docker build | `docker compose run build` |
| Docker shell | `docker compose run dev` |
| Run all checks | `nix flake check` |
| Format Nix files | `nix fmt` |
