# AGENTS.md — nixos-device-profiles

Cross-project AI rules are in `~/.config/opencode/rules.md`.

## What this is

NixOS flake for **PineBookPro** (RK3399 laptop). Cross-compiled from x86_64 → aarch64-linux. Three desktop variants:

| Flake attr            | Desktop | Display manager | Accel matrix                   |
|-----------------------|---------|-----------------|--------------------------------|
| `.#PineBookPro` / `.#image-gnome` | GNOME (default) | GDM  | `1,0,0; 0,0,1; 0,1,0` |
| `.#PineBookPro-plasma` / `.#image-plasma` | Plasma 6 | SDDM (Wayland) | `0,0,-1; -1,0,0; 0,1,0` |
| `.#PineBookPro-phosh` | Phosh   | phosh           | `1,0,0; 0,0,1; 0,1,0` |

## Before building

Copy `secrets.nix.example` to `secrets.nix` (gitignored) and edit —
change `initialPassword`, `authorizedKey`, `ssid`, `psk`.

## Key commands

| Action | Command |
|--------|---------|
| Build SD image (GNOME) | `nix build` |
| Build SD image (Plasma) | `nix build .#image-plasma` |
| Build installer image | `nix build .#image-installer-pinetab2` |
| Build u-boot only | `nix build .#uboot` |
| Docker compose check | `docker compose run check` |
| Docker compose build | `docker compose run build` |
| Docker compose shell | `docker compose run dev` |
| Flash SD card | `dd if=result/sd-image/* of=/dev/sdX bs=4M` |
| Remote update | `nixos-rebuild --flake .#PineBookPro switch --target-host user@host --use-remote-sudo --ask-sudo-password` |
| Flash u-boot to SD | `dd if=<store-path>/u-boot-rockchip.bin of=/dev/sdX conv=fsync,notrunc bs=16M seek=32768` |

`nix build .#image-plasma` or `nix build .#image-gnome` builds the SD image directly without creating a nixosConfiguration.

## Checks

Each variant has a fast eval-only check that asserts ~9 option values (hostname, state version, pipewire, accel mount matrix, DE-specific config). Image builds are separate — checks don't compile the kernel.

| Action | Command |
|--------|---------|
| Run all checks | `nix flake check` |
| GNOME check | `nix build .#checks.x86_64-linux.check-gnome` |
| Plasma check | `nix build .#checks.x86_64-linux.check-plasma` |
| Phosh check | `nix build .#checks.x86_64-linux.check-phosh` |

## Quirks & gotchas

- **Hostname is `PineBookPro`** — that's the target name used everywhere.
- **`extra-substituters` and `extra-trusted-public-keys`** are defined at the wrong level in `flake.nix` (on the `nixosConfigurations` attrset, not as NixOS module options). They are effectively dead code. The Cachix binary cache is not actually configured.
- **GNOME rotation**: 90° rotation compensation via `gdctl set` in a `landscape.service` oneshot (udev-triggered on USB keyboard dock). Only in `gnome.nix`.
- **Phosh PAM crash**: `security.pam.services.login.updateWtmp = lib.mkForce false` works around `pam_lastlog2.so` symbol error.
- **Phosh XWayland**: `phocConfig.xwayland = "immediate"` is set.
- **WiFi stability**: `bes2600` powersave is commented out in `config.nix` because it causes `bes2600_pwr_enter_lp_mode, wait pm ind timeout`.
- **SSH is conditional**: `services.openssh.enable` is true only when `authorizedKey` is non-empty. Password auth is disabled.
- **State version**: `25.11` (config.nix), nixpkgs-unstable for main channel, nixpkgs 25.11 for stable.
- **`nixosSystem` args**: `nixpkgs.hostPlatform` and `buildPlatform` must be set via modules, not as top-level `nixosSystem(...)` args (nixpkgs-unstable rejects them).
- **Checks** are eval-only option assertions (no kernel compile). Image builds are separate `nix build .#image-gnome` etc.
- **Plans** for restructuring and adding new devices are in `plans/`.
- **CVE-2026-31431 (Copy Fail)**: `algif_aead` is blacklisted in `config.nix`; nixpkgsStable lock updated to kernel with the upstream fix (May 14). PineTab2 uses a custom 6.18.10 DanctNIX kernel that can't be updated via nixpkgs, so the blacklist is the interim mitigation. **TODO**: Check if DanctNIX has released `linux-pinetab2` ≥ 6.18.22 (the first fixed 6.18.x) and update the kernel src/hash + remove blacklist. Alternatively, cherry-pick the upstream fix commit `a664bf3d603d` onto the current kernel build.
- **PCIe overlay** (`dtOverlayPCIeFix`) is applied to PineTab2 for RK3566 PCIe fix.
- **Installer images** (`.#image-installer-*`) build minimal recovery SD images (no desktop, no home-manager).
- **Docker compose** (`compose.yaml`) runs nix build/check in a container for environments without nix-daemon.
- **`.gitignore`** ignores `/result` and `secrets.nix`.
- **Plans** for restructuring and adding new devices are in `plans/`.
