# Changelog

## [unreleased]

### Added
- **Variant auto-discovery** — `variants/*.nix` files each define a build target (host, desktop, profiles, platform, buildType). `lib/fromVariant.nix` reads the directory and generates `nixosConfigurations`, `packages`, and `checks` automatically. Adding a new build target = dropping a new `.nix` file in `variants/`.
- `lib/fromVariant.nix` — auto-dispatches to the correct builder (rockchip/generic/x86), derives the build artifact (sdImage/isoImage/uBoot), and generates check assertions with device and desktop-specific validation
- `hosts/nixos/X86Pc/default.nix` — added `networking.hostName = "x86pc"` so the x86 variants have a stable hostname (was falling through to settings.nix)
- `hosts/nixos/Aarch64LUKS/default.nix` — inlined filesystem, LUKS, and kernel module config (previously in gitignored `hardware-configuration.nix`)

### Changed
- `flake.nix` — simplified: nixosConfigurations, packages, checks, and formatting all generated from `variants/` via `lib/fromVariant.nix`. Removed `packages.nix` and `checks.nix` (replaced by auto-discovery)
- `profiles/botany-bay/default.nix` — no longer imports `hardware-configuration.nix` (now inlined in Aarch64LUKS device module; the profile is device-agnostic)
- `nixosConfigurations` keys changed from `PineBookPro` → `pinebookpro-gnome`, `PineTab2` → `pinetab2-gnome`, etc. (derived from variant filenames for consistency)
- `packages` keys changed from `image-gnome` → `image-pinebookpro-gnome`, etc.
- `checks` keys changed from `PineBookPro-gnome` → `pinebookpro-gnome`, etc.

### Added
- Cross-compilation overlays for PineBook Pro aarch64 builds:
  - `arcmenu` — added `glib` and `gitMinimal` to nativeBuildInputs
  - `gexiv2` — disabled gtk_doc to avoid gi-docgen target dependency
  - `git` — added build platform C compiler for Rust build scripts
  - `gom` — added `python3` to nativeBuildInputs
  - `gupnp-av` — disabled gtk_doc during cross-compilation
  - `libglycin` — set `CARGO_BUILD_TARGET=aarch64-unknown-linux-gnu` for meson/cargo cross-compilation
  - `pysmbc` — symlink `pkg-config` to cross-compilation wrapper for setup.py

### Fixed
- PineBookPro uBoot reference — use `pkgs.ubootPinebookPro` instead of `rockchip.packages.${buildPlatform}.uBootPinebookPro`
- PineBookPro `allowUnfreePredicate` — added `arm-trusted-firmware-rk3399` to allowed unfree packages

### Changed
- `compose.yaml` — tuned build resource allocation: `max-jobs=2`, `cores=16` for build/check services; `max-jobs=4`, `cores=0` for fmt/dev
- `scripts/deploy.sh` + `compose.yaml` — new `deploy` service that runs `nixos-rebuild --target-host` with SSH key/known_hosts mounts for remote NixOS deployment from within Docker

### Added
- **Install profiles** — composable NixOS modules in `profiles/` that bundle packages, services, and config per use-case:
  - `profiles/base/default.nix` — curl, wget, htop, git, tmux, vim
  - `profiles/development/default.nix` — gcc, clang, llvm, cmake, python3, nodejs, rust, cargo, postgresql (imports base)
  - `profiles/minimal/default.nix` — curl, git
  - Profiles are full NixOS modules, stackable, and can set any option including home-manager
  - Each profile can have an optional companion `secrets.nix` file (gitignored) for API tokens and credentials
- **Per-node secrets** — `settings.nix` restructured with `Common` defaults and `nodes.<name>` overrides for per-device SSH keys, WiFi credentials, and passwords
- `lib/default.nix` — all 5 builders accept `profileModules` (list of profile paths) and `configName` (for per-node settings resolution); loadSecrets helper auto-loads `secrets.nix` companions from each profile directory and passes merged `secrets` via `specialArgs`
- `.#image-dev` — PineBookPro GNOME + base + development profile SD image
- `.#checks.x86_64-linux.PineBookPro-dev` — eval check for dev profile variant
- `.gitignore` pattern `profiles/*.secret.nix` → `profiles/*/secrets.nix` for subdirectory secrets

### Changed
- Profile files restructured from flat `.nix` files to subdirectories: `profiles/<name>/default.nix` with companion `secrets.nix` and `secrets.nix.example` in the same directory
- `lib/default.nix` `loadSecrets` — changed from `removeSuffix ".nix" + ".secret.nix"` to `dirOf + "/secrets.nix"`

### Changed
- Restructured to EmergentMind/nix-config-starter layout:
  - `config.nix` → `hosts/common/core/default.nix`
  - `{gnome,plasma,phosh}.nix` → `hosts/common/optional/`
  - `devices/pinebook-pro.nix` → `hosts/nixos/PineBookPro/default.nix`
  - `devices/pinetab2.nix` → `hosts/nixos/PineTab2/default.nix`
  - `devices/generic-aarch64.nix` → `hosts/nixos/GenericAarch64/default.nix`
  - `devices/x86pc.nix` → `hosts/nixos/X86Pc/default.nix`
  - `home.nix` → `home/_username_/common/core/default.nix`
  - `flake.nix` — now thin, delegates builders to `lib/default.nix`
  - Builder functions (`rockchipOsConfigAarch64`, `osConfigAarch64`, etc.) moved to `lib/default.nix`
- `hosts/common/core/default.nix` — eliminated redundant `settings.nix` re-read; uses `settings` specialArg directly for all attributes (including secrets)
- `flake.nix`, `compose.yaml` — added `cache.nixos.org` to `extra-substituters` with trusted public key for x86_64 binary cache substitution
- `.env.example` — removed `NIX_CONFIG` (now hardcoded in `compose.yaml`)

### Added
- `lib/default.nix` — extracted builder functions from `flake.nix`
- `shell.nix` — dev shell with `nixfmt-tree`, `nix-output-monitor`
- `.envrc` — `use flake` for direnv auto-load
- `justfile` — aliases for `build`, `check`, `update`, `fmt`, `dev`
- `docs/pinebookpro.md`, `docs/pinetab2.md`, `docs/generic-aarch64.md`, `docs/x86pc.md` — per-device documentation with build, flash, u-boot, quirks, and related project links

### Fixed
- `xdg-desktop-portal-1.20.4` integration tests (`dynamiclauncher`, `notification/sound_fd`) failing during x86 PC installer build — added overlay in `devices/x86pc.nix` to disable tests (they need D-Bus/portal services not present in the sandbox)
- `installerConfigX86` — removed `overlayModule` from x86_64 installer config (overlays are for ARM cross-compilation only)

### Added
- `compose.yaml` — `deploy.resources` limits (14 CPUs, 22G RAM) to build service for OOM prevention
- `compose.yaml` — `cat-result` service for extracting built image paths
- **Generic aarch64 device support** — `devices/generic-aarch64.nix` for any extlinux-booting aarch64 SBC (no Rockchip dependency)
- `flake.nix` — renamed Rockchip-specific builders to `rockchipOsConfigAarch64`/`rockchipInstallerConfigAarch64`; new generic `osConfigAarch64`/`installerConfigAarch64` without Rockchip
- `nixosConfigurations.GenericAarch64` — GNOME SD image for generic aarch64
- `nixosConfigurations.GenericAarch64-installer` — installer SD image for generic aarch64
- `packages.nix` — `image-generic-aarch64`, `image-installer-generic-aarch64`
- `checks.nix` — `generic-aarch64-gnome` eval-only check

### Fixed
- `compose.yaml` — changed `extra-trusted-substituters` → `extra-substituters` (works in single-user mode without nix-daemon); added `nabam-nixos-rockchip.cachix.org` to substituters so all builds share the cross-compilation binary cache

### Added
- x86_64 PC installer ISOs — three variants: console (`.#image-installer-x86pc`), GNOME (`.#image-installer-x86pc-gnome`), Plasma (`.#image-installer-x86pc-plasma`). Built natively via `nixpkgs/nixos/modules/installer/cd-dvd/iso-image.nix`, no cross-compilation.
- `devices/x86pc.nix` — generic x86_64 hardware device module
- `checks.nix` — eval-only x86pc checks (console/gnome/plasma)

### Changed
- `config.nix` — moved `boot.kernelParams` and Rockchip binary cache to per-device configs (architecture-agnostic now)
- `devices/pinebook-pro.nix` — added `boot.kernelParams` and `nix.settings` for Rockchip binary cache
- `devices/pinetab2.nix` — added `boot.kernelParams` and `nix.settings` for Rockchip binary cache

### Fixed
- `libqmi` build failure during cross-compilation — added `overlays/libqmi.nix` to disable GTK documentation generation (`-Dgtk_doc=false`)

### Added
- `settings.nix` — tracked user preferences (username, stateVersion, git config, extra packages)
- `compose.yaml` — `git add -f secrets.nix` before nix commands to allow untracked secrets in Docker builds
- `compose.yaml` — `fmt` service for `nix fmt` via Docker compose
- `AGENTS.md` — reminders to use Docker compose for all Nix commands and to run `nix fmt` after editing

### Changed
- **settings-split**: `username` moved from `secrets.nix` (gitignored) → `settings.nix` (tracked)
- `config.nix` — reads `stateVersion`, `username`, `extraSystemPackages` from `settings.nix`
- `home.nix` — reads `stateVersion`, `gitUserName`, `gitUserEmail`, `extraUserPackages` from `settings.nix`
- `devices/pinetab2.nix` — reads `username` from `settings.nix` (via specialArgs) instead of importing `secrets.nix`
- `flake.nix` — imports `settings.nix` and passes it via `specialArgs` to all NixOS and home-manager modules
- `secrets.nix` / `secrets.nix.example` — `username` field removed
- Plan for Qubes OS template qube image output (`plans/qubes-template.md`)
- Plan for standard x86_64 PC support (`plans/x86pc.md`)

### Fixed
- `onnxruntime` cross-compilation failure (`protoc` binary format error) —
  added `overlays/onnxruntime.nix` to force build-native `protoc` during
  aarch64 cross-compilation
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

### Fixed
- `compose.yaml` — `build` service now accepts a flake fragment argument instead of hardcoding `.#image-gnome`

### Changed
- `settings.nix` and `secrets.nix` — merged into a single gitignored `settings.nix`; `settings.nix.example` is the tracked template (review feedback)
- `compose.yaml` — extracted inline shell commands to `scripts/build.sh` and `scripts/check.sh` for readability; image version is now an env var from `.env` (review feedback)
- ACCEL_MOUNT_MATRIX — moved from `gnome.nix`, `phosh.nix`, `plasma.nix` to `devices/pinetab2.nix` with per-desktop conditional (review feedback: PineTab2-specific)
- `flake.nix` — moved check infrastructure (assertions, `mkCheck`) to `checks.nix` (review feedback)
- `phosh.nix` — uses `settings` from `specialArgs` instead of directly importing `secrets.nix`
- `README.md` — shows Docker compose counterparts alongside nix commands; updated for merged settings/secrets (review feedback)
- `plans/` — moved to `ab/chore/device-plans` branch (review feedback: not in this PR scope)

### Added
- `checks.nix` — extracted check infrastructure from `flake.nix`
- `scripts/build.sh`, `scripts/check.sh` — extracted from `compose.yaml`
- `overlays/README.md` — documents the purpose of each overlay (review feedback)
- `.env.example` — template for Docker compose environment variables

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
