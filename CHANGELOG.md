# Changelog

## [unreleased]

### Added
- Plan for Qubes OS template qube image output (`plans/qubes-template.md`)
- Home-manager integration with user package and dotfile management
- `home.nix` — git signing/config, VSCodium extensions, LibreWolf, ungoogled-chromium
- Docker daemon enabled, user added to `docker` group
- Binary cache configuration (flake-level `nixConfig` + system-level `nix.settings`)
- `nix.settings.auto-optimise-store` for store deduplication
- `nix.settings.max-jobs` and `cores` for parallel builds
- `nixfmt-tree` formatter (`nix fmt`)
- `secrets.nix.example` for credential schema reference
- `zramSwap.enable` — compressed RAM swap for 4GB devices
- `dtOverlayPCIeFix` — RK3566 PCIe device tree overlay for PineTab2
- Installer SD image packages (`.#image-installer-*`) — minimal recovery images
- `compose.yaml` — Docker compose services for nix build/check in a container

### Changed
- Split device-specific hardware into `devices/pinebook-pro.nix` and `devices/pinetab2.nix`
- `config.nix` — hostname, iio sensor, wifi powersave moved to device modules
- `config.nix` — `firefox`/`chromium` replaced with system `git`/`htop`
- Desktop files — ACCEL_MOUNT_MATRIX wrapped in `lib.mkIf hardware.sensor.iio.enable`
- `gnome.nix` — `landscape.service` moved to `devices/pinetab2.nix`
- `secrets.nix` — replaced with placeholder values (edit locally)
- `README.md` — rewritten for multi-device + home-manager

### Fixed
- Cachix binary cache was dead code; now configured at both flake and system level
- Removed dead `nixosConfigurations` let-binding with unreachable substituters
- Nested check attrsets → flat names for `nix flake check` compatibility
- **CVE-2026-31431 (Copy Fail)**: blacklisted `algif_aead` kernel module; updated nixpkgsStable lock to kernel with upstream fix
- `compose.yaml` — replaced `/nix:/nix` bind mount with named volume (hid the container's nix binary)
- `compose.yaml` — added `git safe.directory` workaround for git repo ownership check in container
- `flake.lock` — fixed `lastModified` mismatch for `nixpkgsStable` input that broke `nix flake check`
- `flake.nix` — added missing `home-manager` module to `installerConfig` (option not found error)

---

## [fork] 2025 — PineBookPro adaptation

_Based on the [`raboof/pinetab2-nixos`](https://codeberg.org/raboof/pinetab2-nixos) original._

- Forked to add PineBookPro support alongside the original PineTab2 target
- `b/pinebookpro` branch: renamed hostname, switched to PineBookPro u-boot/kernel
- `main` branch: full refactor removing `nixos-hardware` dependency, inline device config,
  eval-only checks framework, `nabam/nixos-rockchip` flake input

---

## [raboof/pinetab2-nixos] 2024–2025 — Original PineTab2 work

_Source: [codeberg.org/raboof/pinetab2-nixos](https://codeberg.org/raboof/pinetab2-nixos)_

### 2025-04 — linux 7.0
- Update to linux 7.0 kernel for PineTab2
- Test with u-boot 2026.01

### 2025-03 — linux 6.19.10
- Kernel 6.9.6 → 6.19.10
- Disable WiFi powersave (bes2600 stability)
- Pre-configure WiFi profile into image
- u-boot with video support

### 2025-02 — phosh support
- Phosh desktop variant
- Rotation configuration for phosh
- Document eMMC installation, bootloader flashing

### 2025-01 — linux 6.19.6
- Kernel update to 6.19.6
- Show boot progress on tty screen

### 2024-12 — plasma + secrets split
- Add Plasma 6 desktop variant
- Move secrets to `secrets.nix`
- Split config into separate GNOME and Plasma images
- Fix password handling

### 2024-11 — autorotate + on-screen keyboard
- Fix autorotation for GNOME
- Enable on-screen keyboard (gjs-osk)
- Add chromium

### 2024-10 — cross-compilation
- Cross-build from x86_64 → aarch64-linux
- Allow remote deploys via `nixos-rebuild`
- Correct autorotation

### 2024-09 — sd card image
- Build SD card image via `nixos-rockchip`
- Initial config structure
- Use upstream `nixos-rockchip` (asonix fork)
