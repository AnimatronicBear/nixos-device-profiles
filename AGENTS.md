# AGENTS.md — nixos-device-profiles

Cross-project AI rules are in `~/.config/opencode/rules.md`.

## What this is

NixOS flake for **PineBookPro** (RK3399 laptop), **PineTab2** (RK3566 tablet),
**generic aarch64** SBCs, and **x86_64 PC installer ISOs**.
ARM targets cross-compiled from x86_64 → aarch64-linux.
x86_64 installer ISOs built natively.

| nixosConfiguration       | Package (image)           | Desktop | Display manager | Accel matrix |
|--------------------------|---------------------------|---------|-----------------|--------------|
| `.#pinebookpro-gnome`    | `.#image-pinebookpro-gnome`     | GNOME (default) | GDM | `1,0,0; 0,0,1; 0,1,0` |
| `.#pinebookpro-plasma`   | `.#image-pinebookpro-plasma`    | Plasma 6 | SDDM (Wayland) | `0,0,-1; -1,0,0; 0,1,0` |
| `.#pinebookpro-phosh`    | —                           | Phosh   | phosh         | `1,0,0; 0,0,1; 0,1,0` |
| `.#pinebookpro-dev`      | `.#image-pinebookpro-dev`       | GNOME + dev profile | GDM | `1,0,0; 0,0,1; 0,1,0` |
| `.#pinebookpro-installer`| `.#image-pinebookpro-installer` | —       | —             | N/A |
| `.#pinetab2-gnome`       | `.#image-pinetab2-gnome`        | GNOME   | GDM | (see device module) |
| `.#pinetab2-plasma`      | `.#image-pinetab2-plasma`       | Plasma 6 | SDDM (Wayland) | (see device module) |
| `.#pinetab2-phosh`       | —                           | Phosh   | phosh         | (see device module) |
| `.#pinetab2-installer`   | `.#image-pinetab2-installer`    | —       | —             | N/A |
| `.#generic-aarch64-gnome`| `.#image-generic-aarch64-gnome` | GNOME   | GDM | (none) |
| `.#x86pc`                | `.#image-x86pc`                 | Console installer | — | N/A |
| `.#x86pc-gnome`          | `.#image-x86pc-gnome`           | GNOME installer | GDM | N/A |
| `.#x86pc-plasma`         | `.#image-x86pc-plasma`          | Plasma installer | SDDM | N/A |

## Before building

Copy `settings.nix.example` to `settings.nix` (gitignored) and edit —
change `initialPassword`, `authorizedKey`, `ssid`, `psk`, `username`, etc.

## Key commands

| Action | Command |
|--------|---------|
| Build SD image (PineBookPro GNOME) | `nix build` |
| Build SD image (PineBookPro Plasma) | `nix build .#image-pinebookpro-plasma` |
| Build SD image (PineTab2 GNOME) | `nix build .#image-pinetab2-gnome` |
| Build generic aarch64 GNOME image | `nix build .#image-generic-aarch64-gnome` |
| Build dev profile image | `nix build .#image-pinebookpro-dev` |
| Build x86_64 ISO (console) | `nix build .#image-x86pc` |
| Build x86_64 ISO (GNOME) | `nix build .#image-x86pc-gnome` |
| Build x86_64 ISO (Plasma) | `nix build .#image-x86pc-plasma` |
| Build u-boot only | `nix build .#uboot` |
| Docker compose check | `docker compose run check` |
| Docker compose build | `docker compose run build` |
| Docker compose shell | `docker compose run dev` |
| Flash SD card | `dd if=result/sd-image/* of=/dev/sdX bs=4M` |
| Remote update | `nixos-rebuild --flake .#pinebookpro-gnome switch --target-host user@host --use-remote-sudo --ask-sudo-password` |
| Flash u-boot to SD | `dd if=<store-path>/u-boot-rockchip.bin of=/dev/sdX conv=fsync,notrunc bs=16M seek=32768` |

## Checks

Each variant has a fast eval-only check that asserts ~9 option values (hostname, state version, pipewire, accel mount matrix, DE-specific config). Image builds are separate — checks don't compile the kernel.

| Action | Command |
|--------|---------|
| Run all checks | `nix flake check` |
| GNOME check | `nix build .#checks.x86_64-linux.pinebookpro-gnome` |
| Plasma check | `nix build .#checks.x86_64-linux.pinebookpro-plasma` |
| Phosh check | `nix build .#checks.x86_64-linux.pinebookpro-phosh` |
| Dev profile check | `nix build .#checks.x86_64-linux.pinebookpro-dev` |
| Generic aarch64 check | `nix build .#checks.x86_64-linux.generic-aarch64-gnome` |
| x86_64 console check | `nix build .#checks.x86_64-linux.x86pc` |
| x86_64 GNOME check | `nix build .#checks.x86_64-linux.x86pc-gnome` |
| x86_64 Plasma check | `nix build .#checks.x86_64-linux.x86pc-plasma` |

## Structure

```
flake.nix              — thin: delegates to lib/, hosts/, variants/
lib/
  default.nix          — builder functions (rockchipOsConfigAarch64, osConfigAarch64, etc.)
  fromVariant.nix      — variant auto-discovery, builder dispatch, check generation
variants/              — one .nix file per build target (host + desktop + profiles + platform + buildType)
hosts/
  common/
    core/default.nix   — shared NixOS baseline (stateVersion, users, SSH, pipewire, etc.)
    optional/
      gnome.nix        — GNOME desktop config
      plasma.nix       — Plasma 6 desktop config
      phosh.nix        — Phosh desktop config
  nixos/
    PineBookPro/       — device module (uBoot, kernel, firmware)
    PineTab2/          — device module (uBoot, kernel, firmware, IIO, landscape)
    GenericAarch64/    — generic extlinux-booting aarch64 SBC (no Rockchip)
    X86Pc/             — x86_64 PC installer (ISO image)
    Aarch64LUKS/       — aarch64 with LUKS + FIDO2 + systemd-boot (e.g. botany-bay)
home/_username_/common/core/default.nix  — home-manager config
profiles/              — composable profiles (base, development, minimal, botany-bay)
profiles/*/secrets.nix — gitignored per-profile secrets (API tokens, credentials)
overlays/              — cross-compilation fixes
```

## Quirks & gotchas

- **Hostname** is set in `settings.nix` (`hostName`), used via `lib.mkDefault`.
- **Binary cache**: `nabam-nixos-rockchip.cachix.org` configured per-device in `hosts/nixos/PineBookPro/default.nix` and `hosts/nixos/PineTab2/default.nix`. Also in `hosts/nixos/GenericAarch64/default.nix` for shared cross-compiled packages.
- **GNOME rotation**: 90° rotation compensation via `gdctl set` in a `landscape.service` oneshot (udev-triggered on USB keyboard dock). Only in `hosts/nixos/PineTab2/default.nix`.
- **Phosh PAM crash**: `security.pam.services.login.updateWtmp = lib.mkForce false` works around `pam_lastlog2.so` symbol error.
- **Phosh XWayland**: `phocConfig.xwayland = "immediate"` is set.
- **WiFi stability**: `bes2600` powersave is disabled in `hosts/nixos/PineTab2/default.nix` because it causes `bes2600_pwr_enter_lp_mode, wait pm ind timeout`.
- **SSH is conditional**: `services.openssh.enable` is true only when `authorizedKey` is non-empty. Password auth is disabled.
- **State version**: `25.11` (hosts/common/core/default.nix), nixpkgs-unstable for main channel, nixpkgs 25.11 for stable.
- **`nixosSystem` args**: `nixpkgs.hostPlatform` and `buildPlatform` must be set via modules, not as top-level `nixosSystem(...)` args (nixpkgs-unstable rejects them).
- **Checks** are eval-only option assertions (no kernel compile). Image builds are separate.
- **CVE-2026-31431 (Copy Fail)**: `algif_aead` is blacklisted in `hosts/common/core/default.nix`; nixpkgsStable lock updated to kernel with the upstream fix (May 14). PineTab2 uses a custom 6.18.10 DanctNIX kernel that can't be updated via nixpkgs, so the blacklist is the interim mitigation.
- **PCIe overlay** (`dtOverlayPCIeFix`) is applied to PineTab2 for RK3566 PCIe fix.
- **Installer images** (`.#image-installer-*`) build minimal recovery SD images (no desktop, no home-manager) for ARM targets, and standard NixOS ISOs for x86_64 PC targets.
- **Docker compose** (`compose.yaml`) runs nix build/check in a container for environments without nix-daemon.
- **`.gitignore`** ignores `/result`, `settings.nix`, `.env`, and `profiles/*/secrets.nix`.
- **Profiles** are composable NixOS modules in `profiles/<name>/default.nix`. Stack them in `flake.nix` via `profileModules` builder argument. Each profile can have an optional `secrets.nix` companion in the same directory (gitignored) — secrets are auto-loaded and merged into a `secrets` specialArg.
- **Per-node settings** — `settings.nix` supports `Common` + `nodes.<name>` structure. Pass `configName` to the builder to resolve per-node overrides. Backward-compatible: flat `settings.nix` works when `nodes` attr is absent.
