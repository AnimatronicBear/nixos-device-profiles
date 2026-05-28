# nixos-device-profiles

**⚠ WIP — NOT FUNCTIONAL. Do not use for production or anything security-sensitive.**

Multi-device NixOS flake — cross-compiled from x86_64 → aarch64-linux.
Currently supports **PineBookPro** (RK3399), **PineTab2** (RK3566),
**generic aarch64** SBCs, and **x86_64 PC** installer ISOs (native build).

Forked from [raboof/pinetab2-nixos](https://codeberg.org/raboof/pinetab2-nixos)
(PineTab2-only).

Mirrored on [Codeberg](https://codeberg.org/AnimatronicBear/nixos-device-profiles)
and [GitHub](https://github.com/AnimatronicBear/nixos-device-profiles).

**⚠ LLM Assisted / Generated Experimental Work**
Post-fork changes (settings split, device modules, overlays,
CI structure) are **largely LLM-generated and have not been thoroughly reviewed by a
human.** The flake may eval but images may fail to build or boot, and
configuration may be insecure. Use at your own risk.

## Supported configurations

| Device | Desktop | Flake attr | Testing |
|--------|---------|------------|---------|
| PineBookPro | GNOME (default) | `.#PineBookPro` / `.#image-gnome` | ✗ untested |
| PineBookPro | Plasma 6 | `.#PineBookPro-plasma` / `.#image-plasma` | ✗ untested |
| PineBookPro | Phosh | `.#PineBookPro-phosh` | ✗ untested |
| PineTab2 | GNOME | `.#PineTab2` / `.#image-pinetab2-gnome` | ✗ untested |
| PineTab2 | Plasma 6 | `.#PineTab2-plasma` / `.#image-pinetab2-plasma` | ✗ untested |
| PineTab2 | Phosh | `.#PineTab2-phosh` | ✗ untested |
| Generic aarch64 | GNOME | `.#GenericAarch64` / `.#image-generic-aarch64` | ✗ untested |
| Generic aarch64 | Installer | `.#GenericAarch64-installer` / `.#image-installer-generic-aarch64` | ✗ untested |
| x86_64 PC | Installer (console) | `.#image-installer-x86pc` | ✗ untested |
| x86_64 PC | Installer (GNOME) | `.#image-installer-x86pc-gnome` | ✗ untested |
| x86_64 PC | Installer (Plasma) | `.#image-installer-x86pc-plasma` | ✗ untested |

## Device docs

Device-specific build, flash, u-boot, and remote update instructions:

| Device | Doc |
|--------|-----|
| PineBookPro (RK3399) | [docs/pinebookpro.md](docs/pinebookpro.md) |
| PineTab2 (RK3566) | [docs/pinetab2.md](docs/pinetab2.md) |
| Generic aarch64 SBC | [docs/generic-aarch64.md](docs/generic-aarch64.md) |
| x86_64 PC installer | [docs/x86pc.md](docs/x86pc.md) |

## Before building

### 1. `settings.nix` (gitignored)

Copy `settings.nix.example` to `settings.nix` and edit — set your `username`,
`initialPassword`, `authorizedKey`, `ssid`, `psk`, git config, and
package preferences.

## Building an image

The [Quick reference](#quick-reference) table below lists every buildable
output. Builds run inside a Docker container (no host nix-daemon required):

```shell
docker compose run build                      # PineBookPro GNOME (default)
docker compose run build .#image-plasma
docker compose run build .#image-pinetab2-gnome
docker compose run build .#image-generic-aarch64
docker compose run build .#image-installer-x86pc
```

Flash the result:

```shell
# SD card images (aarch64 ARM targets)
dd if=result/sd-image/* of=/dev/sdX bs=4M

# ISO images (x86_64 PC targets)
dd if=result/iso-image/*.iso of=/dev/sdX bs=4M status=progress
```

## Updating a running system

```shell
nixos-rebuild --flake .#<config> switch \
  --target-host user@host \
  --use-remote-sudo --ask-sudo-password
```

Replace `<config>` with the configuration name (e.g. `PineBookPro`,
`PineTab2`, `GenericAarch64`, `PineBookPro-plasma`).

## Key packages

| Package | Where | Notes |
|---------|-------|-------|
| `git`, `htop` | System (`settings.nix`) | `extraSystemPackages` |
| `docker` | System (`hosts/common/core/default.nix`) | User in `docker` group |
| `librewolf`, `ungoogled-chromium`, `vscodium` | User (`settings.nix`) | `extraUserPackages` |

System packages and user packages are configured in `settings.nix` (see
`settings.nix.example`). User dotfiles (git config, VSCodium extensions,
browser settings) are managed by
[home-manager](https://github.com/nix-community/home-manager) in
`home/_username_/common/core/default.nix`.

## Binary cache

The flake uses `nabam-nixos-rockchip.cachix.org` for pre-built kernels,
u-boot, and firmware (configured at both the flake and NixOS system level).

## Security

**CVE-2026-31431 (Copy Fail)** is mitigated by blacklisting `algif_aead`
in `hosts/common/core/default.nix`. The nixpkgs stable input is updated to a kernel containing
the upstream fix (available for PineBookPro; PineTab2 uses a custom DanctNIX
kernel that relies on the blacklist workaround).

## Docker compose

Run nix build and checks inside a container without a host nix-daemon:

```shell
docker compose run check
docker compose run build              # builds .#image-gnome (default)
docker compose run build .#image-plasma
docker compose run build .#image-pinetab2-gnome
docker compose run build .#image-generic-aarch64
docker compose run build .#image-installer-generic-aarch64
docker compose run dev                # interactive shell
docker compose run fmt
```

A named Docker volume (`nix-store`) is used for `/nix`, preserving the
container's built-in nix binary while caching store paths across runs
(needs root Docker).

Image version and nix config are set in `.env` (copy `.env.example` to `.env`).

## Checks

```shell
nix flake check                    # eval-only, no kernel compilation
docker compose run check

# Individual checks:
nix build .#checks.x86_64-linux.PineBookPro-gnome
docker compose run build .#checks.x86_64-linux.PineBookPro-gnome
nix build .#checks.x86_64-linux.PineTab2-plasma
docker compose run build .#checks.x86_64-linux.PineTab2-plasma
nix build .#checks.x86_64-linux.generic-aarch64-gnome
docker compose run build .#checks.x86_64-linux.generic-aarch64-gnome
nix build .#checks.x86_64-linux.x86pc        # console installer
docker compose run build .#checks.x86_64-linux.x86pc
nix build .#checks.x86_64-linux.x86pc-gnome
docker compose run build .#checks.x86_64-linux.x86pc-gnome
nix build .#checks.x86_64-linux.x86pc-plasma
docker compose run build .#checks.x86_64-linux.x86pc-plasma
```

## Code formatting

```shell
nix fmt                 # uses nixfmt-tree
docker compose run fmt
```

## Quick reference

| Action | nix command | Docker compose |
|--------|-------------|----------------|
| Build image (PineBookPro GNOME) | `nix build` | `docker compose run build` |
| Build image (PineTab2 GNOME) | `nix build .#image-pinetab2-gnome` | `docker compose run build .#image-pinetab2-gnome` |
| Build image (generic aarch64) | `nix build .#image-generic-aarch64` | `docker compose run build .#image-generic-aarch64` |
| Build installer (PineBookPro) | `nix build .#image-installer-pinebookpro` | `docker compose run build .#image-installer-pinebookpro` |
| Build installer (PineTab2) | `nix build .#image-installer-pinetab2` | `docker compose run build .#image-installer-pinetab2` |
| Build installer (generic aarch64) | `nix build .#image-installer-generic-aarch64` | `docker compose run build .#image-installer-generic-aarch64` |
| Build x86_64 ISO (console) | `nix build .#image-installer-x86pc` | `docker compose run build .#image-installer-x86pc` |
| Build x86_64 ISO (GNOME) | `nix build .#image-installer-x86pc-gnome` | `docker compose run build .#image-installer-x86pc-gnome` |
| Build x86_64 ISO (Plasma) | `nix build .#image-installer-x86pc-plasma` | `docker compose run build .#image-installer-x86pc-plasma` |
| Build u-boot (PineBookPro) | `nix build .#uboot` | `docker compose run build .#uboot` |
| Build u-boot (PineTab2) | `nix build .#uboot-pinetab2` | `docker compose run build .#uboot-pinetab2` |
| Run all checks | `nix flake check` | `docker compose run check` |
| Format Nix files | `nix fmt` | `docker compose run fmt` |
| Interactive shell | — | `docker compose run dev` |
