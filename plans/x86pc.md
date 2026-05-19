# Plan: standard x86_64 PC support

## Motivation

The flake currently targets only ARM (aarch64-linux) devices via the
`nabam/nixos-rockchip` flake. Adding a generic x86_64 PC target lets the
same flake manage desktops, laptops, and servers — not just single-board
computers. All existing desktop modules (`gnome.nix`, `plasma.nix`,
`phosh.nix`) and the home-manager config (`home.nix`) work unchanged.

## Key differences from Rockchip devices

| Aspect | Rockchip (existing) | x86_64 PC |
|--------|---------------------|-----------|
| **Architecture** | aarch64-linux | x86_64-linux |
| **Flake dependency** | `nabam/nixos-rockchip` | None (or nixos-hardware) |
| **Kernel** | Custom rockchip vendor kernel | `pkgs.linuxPackages` (generic) |
| **U-Boot** | rockchip U-Boot package | GRUB or systemd-boot |
| **Image type** | SD card image (`sdImageRockchip`) | ISO installer or sdImage |
| **Build platform** | Cross-compiled from x86_64 | Native x86_64 |
| **GPU** | Mali (Panfrost) | Intel/AMD/NVIDIA |
| **Firmware** | rockchip firmware blobs | linux-firmware |
| **nixos-hardware** | Not used (analysed, not worth it) | Useful for ThinkPad, Framework, etc. |

## Approach: generic x86_64 config function

```nix
# lib/default.nix (addition to existing osConfig, rpiConfig, imxConfig, etc.)
mkX86Config = buildPlatform: hostModule: variantModule:
  nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      { nixpkgs.buildPlatform = buildPlatform; }
      home-manager.nixosModules.home-manager
      ./hosts/common/core
      hostModule
      variantModule
    ];
  };
```

When building natively on x86_64, `buildPlatform = "x86_64-linux"` (native).
Cross-building from aarch64 is also possible but unusual.

### Image types: sdImage vs isoImage

For x86_64, the standard output is an **ISO installer image**, not an SD card
image. However, `sdImage` also works for writing to USB drives.

```nix
packages.x86_64-linux = {
  iso-gnome = (mkX86Config "x86_64-linux" ./hosts/nixos/X86Pc ./hosts/common/optional/gnome
    ).config.system.build.isoImage;
  iso-plasma = (mkX86Config "x86_64-linux" ./hosts/nixos/X86Pc ./hosts/common/optional/plasma
    ).config.system.build.isoImage;
};
```

The ISO builder uses `modulesPath + "/installer/cd-dvd/iso-image.nix"` from
nixpkgs — the standard NixOS installer ISO. This gives a bootable ISO with:
- UEFI + BIOS support
- systemd-boot or GRUB
- NixOS installer

Or use `sdImage` for a USB-writable image:
```nix
(modulesPath + "/installer/sd-card/sd-image.nix")
```

## Device module: generic x86_64

```nix
# hosts/nixos/X86Pc/default.nix
{ lib, pkgs, config, ... }: {
  networking.hostName = "x86pc";

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Generic x86_64 kernel
  boot.kernelPackages = pkgs.linuxPackages;

  # Firmware
  hardware.enableRedistributableFirmware = true;

  nixpkgs.config.allowUnfree = true;
}
```

### nixos-hardware integration

For specific laptops/desktops, add `nixos-hardware` as a flake input and
import the appropriate hardware module in the host config:

```nix
# hosts/nixos/Framework13/default.nix (optional, future)
{ lib, pkgs, config, nixos-hardware, ... }: {
  imports = [
    nixos-hardware.nixosModules.framework-13-11th-gen-intel
  ];
  networking.hostName = "framework13";
  # ...
}
```

Since `raspberrypi4.md` and `librem5.md` already plan to add `nixos-hardware`
as a flake input, x86_64 laptops can reuse it at zero additional cost.

## How existing files map

| File | x86_64 usage | Change needed |
|------|-------------|---------------|
| `hosts/common/core/default.nix` (was `config.nix`) | Full reuse — SSH, users, pipewire, docker, NetworkManager | None |
| `hosts/common/optional/gnome.nix` (was `gnome.nix`) | Full reuse | Remove ACCEL_MOUNT_MATRIX condition (no iio sensor on x86) or wrap in `lib.mkIf` |
| `hosts/common/optional/plasma.nix` (was `plasma.nix`) | Full reuse | Same — ACCEL_MOUNT_MATRIX is conditional already |
| `hosts/common/optional/phosh.nix` (was `phosh.nix`) | Works but unusual on x86 | No change needed |
| `home/bear/common/core/default.nix` (was `home.nix`) | Full reuse | None |
| `hosts/common/secrets/default.nix` (was `secrets.nix`) | Full reuse | None |
| `checks.nix` | Needs x86_64-specific assertions | Add `device == "X86Pc"` branch |

## Desktop variants

| Variant | x86_64 support | Notes |
|---------|---------------|-------|
| **GNOME** | Full | Intel/AMD GPU works out of box; NVIDIA needs proprietary driver |
| **Plasma 6** | Full | Same |
| **Phosh** | Works | Unusual on desktop but functional |
| **Headless/minimal** | Full | Server config, no GUI (useful as Qubes template base) |

All three desktop files work on x86_64 as-is. The ACCEL_MOUNT_MATRIX
settings in `gnome.nix`, `plasma.nix`, and `phosh.nix` are wrapped in
`lib.mkIf config.hardware.sensor.iio.enable`, so they're no-ops on x86_64
hardware that lacks an IIO accelerometer.

## Flake outputs

```nix
# flake.nix additions
nixosConfigurations = {
  # ... existing ARM configs ...

  X86Pc-gnome  = mkX86Config "x86_64-linux" ./hosts/nixos/X86Pc ./hosts/common/optional/gnome;
  X86Pc-plasma = mkX86Config "x86_64-linux" ./hosts/nixos/X86Pc ./hosts/common/optional/plasma;
  X86Pc-phosh  = mkX86Config "x86_64-linux" ./hosts/nixos/X86Pc ./hosts/common/optional/phosh;
};

packages.x86_64-linux = {
  # ... existing packages ...

  iso-image-gnome = (mkX86Config system ./hosts/nixos/X86Pc ./hosts/common/optional/gnome
    ).config.system.build.isoImage;
  iso-image-plasma = (mkX86Config system ./hosts/nixos/X86Pc ./hosts/common/optional/plasma
    ).config.system.build.isoImage;

  # USB-writable SD image (alternative to ISO)
  usb-image-gnome = (mkX86Config system ./hosts/nixos/X86Pc ./hosts/common/optional/gnome
    ).config.system.build.sdImage;

  # Installer-style images (copies the ISO's installer onto a USB image)
  installer-iso = (mkX86Config system ./hosts/nixos/X86Pc ./hosts/common/optional/gnome
    ).config.system.build.installerIsoImage;
};
```

Note: `system` here is `x86_64-linux` (from `utils.lib.eachDefaultSystem`),
so these packages appear under `packages.x86_64-linux` and can only be built
on x86_64 machines (natively) or via remote builders.

### Check assertions

```nix
# checks.nix addition
X86Pc-gnome = mkCheck "X86Pc" ./hosts/nixos/X86Pc ./hosts/common/optional/gnome "gnome";
X86Pc-plasma = mkCheck "X86Pc" ./hosts/nixos/X86Pc ./hosts/common/optional/plasma "plasma";
X86Pc-phosh = mkCheck "X86Pc" ./hosts/nixos/X86Pc ./hosts/common/optional/phosh "phosh";
```

With `mkCheck` updated to handle `X86Pc`:
- `hostName`: `"X86Pc"`
- iio sensor: disabled (no accelerometer on typical x86 PC)
- No `landscape.service`
- No `extraHwdb` ACCEL_MOUNT_MATRIX
- `system.stateVersion`: `"25.11"`

## Cross-compilation note

Cross-compiling x86_64 images from aarch64 is technically possible with
`buildPlatform = "aarch64-linux"` and `hostPlatform = "x86_64-linux"`, but
is slow and rarely useful. In practice:
- Build x86_64 images **natively on x86_64** hardware
- ARM images are **cross-compiled from x86_64** (current workflow)
- Both outputs coexist in the same flake

## Builder caching

x86_64 builds can use the standard `nixos.org` binary cache (unlike ARM
builds which rely on `nabam-nixos-rockchip.cachix.org`). Most packages
will be pre-built and cached.

## Relationship to order-of-operations.md

```
emergentmind-restructure.md
    │
    ├──► rockpro64.md (same SoC)
    ├──► raspberrypi4.md ─┐ (nixos-hardware)
    ├──► librem5.md      ─┘
    ├──► orangepi5ultra.md (new flake: rk3588)
    ├──► X86Pc.md         ← HERE (no new flake input needed)
    └──► pinephonepro.md (conditional)
```

x86_64 PC is independent of all other device ports. It needs no new flake
inputs. It can be done any time after the emergentmind restructure, in
parallel with any other device plan.

## Implementation phases

| Phase | What | Files |
|-------|------|-------|
| **1** | Add `mkX86Config` function to lib | `lib/default.nix` |
| **2** | Create device module | `hosts/nixos/X86Pc/default.nix` |
| **3** | Add nixosConfigurations for 3 desktop variants | `flake.nix` |
| **4** | Add ISO + SD image packages (x86_64-linux) | `flake.nix` |
| **5** | Add check assertions for X86Pc | `checks.nix` |
| **6** | Build ISO and test in VM | shell |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| ISO builder requires GRUB or systemd-boot config | Build failure on missing bootloader | Default systemd-boot is fine for UEFI; GRUB for BIOS fallback |
| NVIDIA GPU requires proprietary drivers | Poor UX if not configured | Document `hardware.opengl.extraPackages` for NVIDIA; add optional `nvidia.nix` submodule |
| ISO and sdImage builders have different module paths | Wrong builder gives cryptic error | Test both early in phase 6 |
| Wi-Fi firmware not included on generic ISO | No network in installer | `hardware.enableRedistributableFirmware = true` pulls in linux-firmware |
