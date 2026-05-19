# Plan consolidation and order of operations

## Plans inventory

| Plan | Flake inputs | Platform | Effort | Depends on |
|------|-------------|----------|--------|------------|
| `settings-split.md` | None | All | Small | Nothing |
| `emergentmind-restructure.md` | None | All | Large | settings-split |
| `codeberg-ci.md` | None | infra | Medium | restructure (paths) |
| `rockpro64.md` | None | RK3399 | Tiny | restructure |
| `x86pc.md` | None (nixos-hardware optional) | x86_64 | Small | restructure |
| `raspberrypi4.md` | `nixos-hardware` | BCM2711 | Medium | restructure |
| `librem5.md` | `nixos-hardware` (shared) | i.MX8M | Medium | restructure, settings-split |
| `orangepi5ultra.md` | `gnull/nixos-rk3588` | RK3588 | Medium | restructure |
| `qubes-template.md` | evq packages (copied) | x86_64 RPM | Large | restructure |
| `pinephonepro.md` | None (maybe megi kernel) | RK3399S | Conditional | restructure, settings-split |

## Cross-plan dependencies

```
settings-split (username out of secrets; unblocks phosh.nix for Librem5/PPP)
    │
    ▼
emergentmind-restructure (new layout: hosts/, lib/, checks.nix, etc.)
    │
    ├──► codeberg-ci (CI paths depend on restructured layout)
    │
    ├──► rockpro64 (same RK3399 SoC, no new inputs — trivial validation)
    │
    ├──► x86pc (generic x86_64, no new inputs — validates x86_64 path in lib/)
    │
    ├──► raspberrypi4 ─┐ (nixos-hardware, one input, two+ devices)
    ├──► librem5      ─┘
    │
    ├──► orangepi5ultra (gnull/nixos-rk3588 input)
    │
    ├──► qubes-template (Qubes RPM packaging, x86_64 only)
    │
    └──► pinephonepro (conditional: probe rockchip flake for PPP DT first)
```

## Consolidation opportunities

### 1. `nixos-hardware` flake input added by multiple plans

`raspberrypi4.md`, `librem5.md`, and optionally `x86pc.md` (for Framework,
ThinkPad, etc.) all use `nixos-hardware`. Add it **once**, use it everywhere.

### 2. Config function explosion

Every platform needs its own `mkSystem` variant. They differ only in system
arch, specialArgs, and which SD/ISO image module to use:

| Plan | Config function | System | Image module |
|------|----------------|--------|-------------|
| Existing (rockchip) | `osConfig` | aarch64 | `sdImageRockchip` |
| `x86pc.md` | `mkX86Config` | x86_64 | `isoImage` / `sdImage` |
| `raspberrypi4.md` | `rpiConfig` | aarch64 | generic `sdImage` |
| `librem5.md` | `imxConfig` | aarch64 | generic `sdImage` |
| `orangepi5ultra.md` | `rk3588Config` | aarch64 | rk3588 `sdImage` |

**Consolidate into a single `mkSystem` in `lib/default.nix`:**

```nix
mkSystem = { system, buildPlatform, sdImageModule, specialArgs ? {}, extraModules ? [] }: hostModule: variantModule:
  nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit rockchip buildPlatform; } // specialArgs;
    modules = [
      { nixpkgs.hostPlatform = system; }
      { nixpkgs.buildPlatform = buildPlatform; }
      sdImageModule or (if system == "x86_64-linux" then [] else [])
      rockchip.nixosModules.noZFS or (if system != "aarch64-linux" then [])
      home-manager.nixosModules.home-manager
      ./hosts/common/core
      hostModule
      variantModule
    ] ++ extraModules;
  };
```

Then each platform becomes a thin wrapper:

```nix
osConfig = mkSystem {
  system = "aarch64-linux";
  sdImageModule = rockchip.nixosModules.sdImageRockchip;
  specialArgs = { inherit rockchip; };
};
mkX86Config = mkSystem {
  system = "x86_64-linux";
  sdImageModule = [];  # uses isoImage instead
};
rpiConfig = mkSystem {
  system = "aarch64-linux";
  sdImageModule = [];  # generic sdImage
  specialArgs = { inherit nixos-hardware; };
};
```

### 3. `mkCheck` assertion table

Every device adds a `device == "X"` branch to `mkCheck`. Refactor to a
data-driven list in `checks.nix`:

```nix
deviceSpecs = {
  PineBookPro = { iio = false; landscape = false; accel = null; stateVersion = "25.11"; };
  PineTab2    = { iio = true;  landscape = true;  accel = "1, 0, 0; 0, 0, 1; 0, 1, 0"; stateVersion = "25.11"; };
  RockPro64   = { iio = false; landscape = false; accel = null; stateVersion = "25.11"; };
  X86Pc       = { iio = false; landscape = false; accel = null; stateVersion = "25.11"; };
  RPi4        = { iio = false; landscape = false; accel = null; stateVersion = "25.11"; };
  # ... etc
};
```

This eliminates repetitive `if device == ...` chains.

### 4. `phosh.nix` user fix blocks two devices

`phosh.nix` does `(import ./secrets.nix).username` — both `librem5.md` and
`pinephonepro.md` call this out as a blocker. `settings-split.md` is the
hard prerequisite. Do `settings-split` before any Phosh device port.

### 5. ACCEL_MOUNT_MATRIX belongs in device modules, not DE modules

Currently `gnome.nix`, `plasma.nix`, `phosh.nix` each set their own matrix
conditionally. The device knows its sensor orientation; the DE only knows
which direction convention it uses. Move the matrix to per-device hardware
configs (`hosts/nixos/*/hardware.nix`), keep only the direction convention
in the DE module.

### 6. Cross-platform builder caching

| Platform | Binary cache | Status |
|----------|-------------|--------|
| aarch64 (rockchip) | `nabam-nixos-rockchip.cachix.org` | Configured but broken (dead code) |
| aarch64 (RPi4, Librem5) | `cache.nixos.org` | Works automatically |
| x86_64 (PC, Qubes) | `cache.nixos.org` | Works automatically |

Fix the Cachix config as part of `codeberg-ci.md`.

## Recommended order of operations

### Phase 0 — Planning (done)

All plans written: `settings-split.md`, `emergentmind-restructure.md`,
`codeberg-ci.md`, `rockpro64.md`, `x86pc.md`, `raspberrypi4.md`,
`librem5.md`, `orangepi5ultra.md`, `qubes-template.md`, `pinephonepro.md`.

### Phase 1 — Infrastructure (no new devices)

```
Step 1: settings-split.md
  Creates settings.nix, moves username/git config/extraPackages out of
  secrets.nix into a tracked settings file.
  Unblocks phosh.nix for Librem5 and PinePhonePro.
  Files: settings.nix (new), secrets.nix (trimmed), config.nix, home.nix,
         devices/pinetab2.nix, flake.nix, README.md

Step 2: emergentmind-restructure.md
  Flat root files → hosts/, home/, lib/, checks.nix, modules/, overlays/.
  Creates shell.nix, .envrc, justfile for dev workflow.
  Consolidates osConfig/installerConfig into lib/default.nix.
  ALL subsequent steps use the new paths.
```

### Phase 2 — CI + validation (no new flake inputs)

```
Step 3: codeberg-ci.md
  Woodpecker CI pipelines: eval checks on push, image builds on tag.
  Fix Cachix config so binary cache actually works.
  Files: .woodpecker/*.yml, config.nix (Cachix fix)

Step 4: rockpro64.md
  Same RK3399 SoC as PineBookPro — simplest possible device add.
  Validates that the emergentmind structure works for new hosts.
  Files: hosts/nixos/RockPro64/default.nix, flake.nix, checks.nix

Step 5: x86pc.md
  Generic x86_64 PC — validates x86_64 build path in lib/.
  ISO installer images, UEFI+BIOS boot, no new flake inputs needed.
  Files: hosts/nixos/X86Pc/default.nix, flake.nix, checks.nix
  Parallel with Step 4 (no shared dependencies).
```

### Phase 3 — Devices with nixos-hardware

```
Step 6: raspberrypi4.md + librem5.md (one pass)
  Add nixos-hardware flake input once, add both device modules.
  RPi4: bcm2711 kernel, GPU firmware, generic sdImage.
  Librem5 (+ Devkit): i.MX8M kernel/U-Boot from nixos-hardware, Phosh DE.
  Files: flake.nix, hosts/nixos/{RPi4,Librem5,Librem5-devkit}/default.nix,
         checks.nix
```

### Phase 4 — Devices with their own flake inputs

```
Step 7: orangepi5ultra.md
  Add gnull/nixos-rk3588. RK3588 vendor kernel, Mali G610, PCIe NVMe, 2.5GbE.
  Files: flake.nix, hosts/nixos/OrangePi5Ultra/default.nix, checks.nix
```

### Phase 5 — Specialized outputs

```
Step 8: qubes-template.md
  x86_64 RPM package for Qubes dom0. Qubes guest agent packages/modules
  sourced from evq/qubes-nixos-template. RPM builder + optional ISO.
  Files: qubes/pkgs/*, qubes/modules/*, qubes/tools/rpm.nix, qubes/profiles/*,
         qubes/configs/*, flake.nix
  Can be done in parallel with Phases 3-4 (different architecture, no shared
  flake inputs).
```

### Phase 6 — Conditional / stretch

```
Step 9: pinephonepro.md (conditional)
  Probe nabam/nixos-rockchip for PPP device tree first. If present, trivial
  (~5 lines). If not, package megi kernel in pkgs/kernel-pinephonepro/.
  Files: hosts/nixos/PinePhonePro/default.nix, flake.nix, checks.nix,
         (maybe) pkgs/kernel-pinephonepro/
```

## Summary dependency graph

```
settings-split
    │
    ▼
restructure (emergentmind)
    │
    ├──► codeberg-ci          (CI pipelines, Cachix fix)
    │
    ├──► rockpro64            (same RK3399, trivial)
    ├──► x86pc                (generic x86_64, no new inputs)
    │       (parallel — independent)
    │
    ├──► raspberrypi4 ─┐     (nixos-hardware, one input)
    ├──► librem5      ─┘     (reuses same input)
    │
    ├──► orangepi5ultra       (gnull/nixos-rk3588 input)
    │
    ├──► qubes-template       (x86_64 RPM, independent)
    │       (parallel with Phases 3-4 — different arch)
    │
    └──► pinephonepro         (conditional on rockchip flake DT)
```

## What NOT to do

- Don't add `mobile-nixos` as a flake input (incompatible module system)
- Don't add `nixos-hardware` for PineBookPro or PineTab2 (already covered
  by `nabam/nixos-rockchip` + manual config)
- Don't create per-device config functions (`rk3588Config`, `rpiConfig`,
  `imxConfig`, `mkX86Config`) as separate functions — consolidate into
  one `mkSystem` in `lib/default.nix`
- Don't add x86_64 PC support before the restructure — the generic config
  function pattern only makes sense in the new `lib/default.nix`
- Don't build Qubes template before verifying it works with a minimal x86_64
  config first (Phase 2, Step 5 validates x86_64 build path)
- Don't implement `pinephonepro.md` without first probing the rockchip flake
  for the PPP device tree — it could be trivial
