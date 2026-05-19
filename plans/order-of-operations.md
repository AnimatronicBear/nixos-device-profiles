# Plan consolidation and order of operations

## Plans inventory

| Plan | New flake inputs | Custom kernel? | Paths referenced |
|------|-----------------|---------------|------------------|
| `settings-split.md` | None | No | `secrets.nix`, `config.nix`, `devices/*.nix`, `home.nix`, `flake.nix` |
| `emergentmind-restructure.md` | None | No | All root `.nix` → moved to `hosts/`, `home/`, `lib/`, etc. |
| `rockpro64.md` | None | No (same kernel as PineBookPro) | `devices/rockpro64.nix`, `flake.nix` |
| `raspberrypi4.md` | `nixos-hardware` | No (vendor kernel from hardware module) | `devices/rpi4.nix`, `flake.nix` |
| `librem5.md` | `nixos-hardware` | No (vendor kernel from hardware module) | `devices/librem5.nix`, `flake.nix`, `phosh.nix` |
| `orangepi5ultra.md` | `gnull/nixos-rk3588` | Vendor kernel from rk3588 flake | `devices/orangepi5ultra.nix`, `flake.nix` |
| `pinephonepro.md` | None (maybe) | Maybe — megi fork if rockchip flake lacks DT | `devices/pinephonepro.nix`, `flake.nix`, `phosh.nix` |

## Cross-plan dependencies

```
settings-split.md ──→ emergentmind-restructure.md ──→ rockpro64.md
                     (moves all paths, lib/, checks.nix)  │
                           │                              ├──→ raspberrypi4.md (nixos-hardware)
                           │                              ├──→ librem5.md       (nixos-hardware, same input)
                           │                              ├──→ orangepi5ultra.md (gnull/nixos-rk3588)
                           │                              └──→ pinephonepro.md  (maybe custom kernel)
                           │
                           └──  phosh.nix fixed (settings-split: no hardcoded ./secrets.nix import)
                                  │
                                  ├── needed by librem5.md
                                  └── needed by pinephonepro.md
```

## Consolidation opportunities

### 1. Flake input: `nixos-hardware` added twice

Both `raspberrypi4.md` and `librem5.md` add `nixos-hardware` as a flake input.
These should be **one change**: add the input once, add both device modules in
the same PR/commit.

### 2. Config function explosion

Every device port plan adds a new `*Config` function to `flake.nix`:

| Plan | Config function |
|------|----------------|
| existing | `osConfig` (rockchip SD image builder) |
| existing | `installerConfig` (rockchip installer builder) |
| `raspberrypi4.md` | `rpiConfig` (generic `sdImage`) |
| `librem5.md` | `imxConfig` (generic `sdImage`) |
| `orangepi5ultra.md` | `rk3588Config` (rk3588 SD image builder) |

After the restructure, these all live in `lib/default.nix`. They share
most of their structure (modules list) — they differ only in:
- Which flake's sdImage module is used (rockchip vs. generic vs. rk3588)
- Which `specialArgs` are passed

Consolidation idea: a single `mkSystem` that takes the SD image module
and special args as parameters, rather than N separate functions.

### 3. `mkCheck` assertions grow with each device

Every device plan adds a `device == "MyDevice"` branch to `mkCheck` in
`flake.nix`. After the restructure, this is in `checks.nix`.

The pattern is already repetitive — each branch checks hostName, iio,
landscape.service, accel matrix, stateVersion. Could be refactored to a
data-driven approach (a list of device specs with expected properties),
but that can be deferred.

### 4. `phosh.nix` user fix is needed by two plans

`phosh.nix` currently does `(import ./secrets.nix).username` at the top.
Both `librem5.md` (step 7) and `pinephonepro.md` (step 7) call out this
as a blocker. The `settings-split.md` fix resolves it.

**This is a hard prerequisite** — phosh on any new device (Librem 5,
PinePhone Pro) depends on it. Do settings-split before adding those devices.

### 5. ACCEL_MOUNT_MATRIX appears in three DE modules + two device modules

Currently:
- `gnome.nix`, `plasma.nix`, `phosh.nix` each set `services.udev.extraHwdb`
  conditionally (`lib.mkIf config.hardware.sensor.iio.enable`)
- `devices/pinetab2.nix` adds `landscape.service` for GNOME-specific rotation
- `devices/pinephonepro.nix` (planned) also has its own ACCEL_MOUNT_MATRIX

Consolidation idea: move ACCEL_MOUNT_MATRIX into the device module
(each device knows its own sensor orientation), not the DE module.
The DE only needs to know about direction conventions (GNOME vs. Plasma
interpret "normal" differently). This is a nice-to-have, not a blocker.

### 6. Kernel packaging for PinePhone Pro

`pinephonepro.md` may need a custom megi kernel package if the
`nabam/nixos-rockchip` flake doesn't include the PinePhone Pro device tree.

Before doing anything, probe the rockchip flake:
```
nix eval github:nabam/nixos-rockchip\#legacyPackages.x86_64-linux.kernel_linux_latest_rockchip_stable.config.system.build.kernel.devicetree
```
to see if `rk3399-pinephone-pro.dtb` is present. If yes, no custom kernel
needed — PinePhone Pro becomes as simple as RockPro64.

## Recommended order of operations

### Phase 1 — Infrastructure (no new devices)

```
Step 1: settings-split.md
  Creates settings.nix, moves username out of secrets.nix.
  Unblocks phosh.nix for later device ports.
  Updates: config.nix, home.nix, devices/pinetab2.nix, flake.nix

Step 2: emergentmind-restructure.md
  Moves files into hosts/, home/, lib/, checks.nix, etc.
  Creates shell.nix, .envrc, justfile for dev workflow.
  ALL subsequent steps use the new paths.
```

### Phase 2 — Simple device (same SoC, same flake, no new inputs)

```
Step 3: rockpro64.md
  Same RK3399 SoC as PineBookPro, same kernel, same nabam/nixos-rockchip flake.
  Adds: hosts/nixos/RockPro64/default.nix + flake.nix entries + checks.nix entry.
  No new flake inputs. No custom packaging.
  Easiest addition — validates the new structure before adding complexity.
```

### Phase 3 — Devices sharing nixos-hardware input

```
Step 4: raspberrypi4.md + librem5.md (in one pass)
  Add nixos-hardware flake input once.
  Add both device modules:
    hosts/nixos/RPi4/default.nix
    hosts/nixos/Librem5/default.nix
    hosts/nixos/Librem5-devkit/default.nix
  RPi4 uses nixos-hardware raspberry-pi-4 module.
  Librem 5 uses nixos-hardware purism-librem-5r4 module.
  Both use generic sdImage builder (not rockchip).
```

### Phase 4 — Devices with their own flake inputs

```
Step 5: orangepi5ultra.md
  Add gnull/nixos-rk3588 flake input.
  Add hosts/nixos/OrangePi5Ultra/default.nix.
  Vendor kernel from rk3588 flake, Mali G610 GPU, 2.5GbE.

Step 6: pinephonepro.md (conditional)
  Probe nabam/nixos-rockchip for PPP DT first.
  If DT exists: ~5 lines of code (same effort as RockPro64).
  If not: package megi kernel in pkgs/kernel-pinephonepro/.
```

## What NOT to do

- Don't add `mobile-nixos` as a flake input. The analysis in both
  `pinephonepro.md` and `librem5.md` concludes it's incompatible with
  the existing infrastructure.
- Don't add `nixos-hardware` for PineBookPro or PineTab2 — the existing
  `nabam/nixos-rockchip` + manual config already covers what's needed.
- Don't create device-specific config functions until after the restructure.
  The `lib/default.nix` in the restructure plan naturally handles this.

## Summary dependency graph

```
settings-split
    │
    ▼
restructure (emergentmind)
    │
    ├──► rockpro64 (same SoC, trivial)
    │
    ├──► raspberrypi4 ─┐ (share nixos-hardware input)
    ├──► librem5      ─┘
    │
    ├──► orangepi5ultra (gnull/nixos-rk3588)
    │
    └──► pinephonepro (conditional — probe rockchip flake first)
```
