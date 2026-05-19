# Plan: add Purism Librem 5 and Devkit support

## Device overview

### Librem 5 (phone)

| Property | Value |
|----------|-------|
| SoC | NXP i.MX8M Quad (4× Cortex-A53 @ 1.5 GHz + Cortex-M4F) |
| GPU | Vivante GC7000Lite (etnaviv, Mesa) |
| RAM | 3 GB LPDDR4 |
| Storage | 32 GB eMMC + microSD |
| Display | 5.7″ 720×1440 MIPI DSI (Mantix panel) |
| Modem | BroadMobi BM818 (M.2, LTE Cat 4) |
| WiFi/BT | SparkLAN WNFB-266AXI(BT) (Wi-Fi 6, BT 5.3) or Redpine RS9116 |
| GNSS | ST Teseo-LIV3F |
| Sensors | LSM9DS1 IMU, VCNL4040 ALS/proximity |
| Battery | 4500 mAh, user-replaceable |
| USB | USB-C 3.0 OTG + PD + DisplayPort |
| Kill switches | 3 physical: modem, WiFi/BT, cameras+mic |
| Kernel DT | `imx8mq-librem5-r4.dts` (upstream) |

### Librem 5 Devkit ("Bean")

| Property | Value |
|----------|-------|
| SoC | Same NXP i.MX8M Quad (on EmCraft SOM) |
| RAM | 2–4 GB LPDDR4 |
| Storage | 16 GB eMMC (on SOM) |
| Display | mini-HDMI (no built-in panel) |
| Modem | SIMCom SIM7100A/E (mPCIe) |
| WiFi/BT | Redpine RS9116 (M.2) |
| Ethernet | 1× Gigabit Ethernet (RJ45) — phone does NOT have this |
| USB | USB-C + multiple USB-A host ports |
| Expansion | 40-pin GPIO header, boot mode switch |
| Battery | 18650 holder (optional) |
| Kernel DT | `imx8mq-librem5-devkit.dts` (upstream) |

---

## Key difference from existing devices

| Aspect | Rockchip devices (existing) | Librem 5 |
|--------|-----------------------------|----------|
| **SoC** | RK3399 / RK3566 / RK3399S / RK3588 | NXP i.MX8M Quad |
| **GPU** | Mali-T860 / G52 / G610 (panfrost) | Vivante GC7000Lite (etnaviv) |
| **Kernel source** | `nabam/nixos-rockchip` vendor kernel | Purism downstream 6.6.y or mainline |
| **U-Boot** | `nabam/nixos-rockchip` packages | Purism downstream fork (extlinux) |
| **Image builder** | `sdImageRockchip` from nixos-rockchip | Standard `sdImage` (generic aarch64) or uuu |
| **Flashing** | `dd` to SD card | Jumpdrive (USB mass storage gadget) |
| **NixOS infra** | External flake (`nabam/nixos-rockchip`) | **nixos-hardware module** (kernel + u-boot + config) |

The Librem 5 is the first non-Rockchip device in this project. It cannot use
`nabam/nixos-rockchip` at all — no i.MX support exists there.

---

## External repo analysis

### nixos-hardware (`github:NixOS/nixos-hardware`)

**Has full support for the Librem 5** at `purism/librem/5r4/`:

| File | Purpose |
|------|---------|
| `default.nix` | Main module — WiFi variant selector, audio config, initrd, lockdown fix |
| `kernel.nix` | Custom kernel `6.6.74-librem5` from Purism GitLab with `librem5_defconfig` |
| `u-boot/default.nix` | Purism's downstream U-Boot fork (adds extlinux support missing from mainline) |
| `wifi.nix` | WiFi module — blacklists `rsi_91x`, loads `redpine_91x` with `dev_oper_mode=13` |
| `audio.nix` | PulseAudio config for modem audio routing |
| `initrd.nix` | Custom initrd kernel modules |
| `lockdown-fix.nix` | Sensor workaround after hardware kill switch lockdown |
| `librem5-base/` | UDEV rules and base packages |

**Does NOT have a separate Devkit module**, but the Devkit can reuse most
of the phone config with different peripheral setup.

### mobile-nixos (`github:mobile-nixos/mobile-nixos`)

**Does NOT support the Librem 5**. No device directory exists. Not relevant.

---

## Recommendation: use nixos-hardware as a flake input

Unlike the PineBookPro case (where nixos-hardware offered trivial overlap),
the Librem 5 situation is different:

| Need | Source |
|------|--------|
| Custom kernel | nixos-hardware (6.6.74-librem5 from Purism GitLab) |
| Custom U-Boot | nixos-hardware (downstream fork with extlinux) |
| WiFi variant handling | nixos-hardware (redpine vs sparklan) |
| Modem audio routing | nixos-hardware (PulseAudio config) |
| Initrd kernel modules | nixos-hardware |
| Lockdown mode fix | nixos-hardware |
| UDEV rules | nixos-hardware |

Without nixos-hardware, we would need to package all of these ourselves.
Adding it as a flake input is the right call here.

### What to add directly in this project

- Device module for the phone (`devices/librem5.nix`) — imports nixos-hardware
  module and adds any project-specific config
- Device module for the Devkit (`devices/librem5-devkit.nix`) — mostly shares
  the phone module but with HDMI output, Ethernet, different modem
- Flake entries for nixosConfigurations, packages, and checks
- Phosh desktop variant (the Librem 5 is a phone — Phosh is the primary DE)

---

## Changes required

### 1. Add flake input — `flake.nix`

```nix
inputs = {
  nixpkgs.url = "nixpkgs/nixos-unstable";
  nixpkgsStable.url = "nixpkgs/nixos-25.11";
  rockchip = {
    url = "github:nabam/nixos-rockchip";
    inputs.nixpkgsStable.follows = "nixpkgsStable";
    inputs.nixpkgsUnstable.follows = "nixpkgs";
  };
  nixos-hardware = {
    url = "github:NixOS/nixos-hardware";
  };
  # ... utils, home-manager unchanged
};
```

### 2. Add i.MX-specific config function — `flake.nix`

```nix
imxConfig = deviceModule: variant:
  nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      { nixpkgs.hostPlatform = "aarch64-linux"; }
      { nixpkgs.buildPlatform = buildPlatform; }
      home-manager.nixosModules.home-manager
      nixos-hardware.nixosModules.purism-librem-5r4
      ./config.nix
      variant
      deviceModule
    ];
  };
```

Note: `nixos-hardware.nixosModules.purism-librem-5r4` provides the kernel,
U-Boot, WiFi config, audio, and initrd. We layer our common `config.nix`
(SSH, pipewire, docker, etc.) on top.

Cross-compilation from x86_64 should work since the i.MX8M kernel and U-Boot
are well-supported in nixpkgs.

### 3. Device module — `devices/librem5.nix`

```nix
{ lib, pkgs, config, ... }: {
  networking.hostName = "Librem5";
  hardware.librem5.wifiCard = lib.mkDefault "sparklan";
  hardware.librem5.audio = true;
  hardware.librem5.customInitrdModules = true;
  hardware.librem5.lockdownFix = true;

  # Phone-specific services
  services.udev.packages = [ pkgs.purism-librem5-udev ];
  environment.systemPackages = [ pkgs.bm818-tools ];

  # The librem5 kernel already includes everything needed
  nixpkgs.config.allowUnfree = true;
}
```

### 4. Device module — `devices/librem5-devkit.nix`

```nix
{ lib, pkgs, config, ... }: {
  networking.hostName = "Librem5Devkit";
  hardware.librem5.wifiCard = "redpine";  # Devkit uses Redpine
  hardware.librem5.audio = false;         # No modem audio on devkit
  hardware.librem5.customInitrdModules = true;
  hardware.librem5.lockdownFix = false;   # No kill switches on devkit

  # Devkit-specific peripherals
  services.xserver.enable = true;          # HDMI output

  # Modem is SIMCom, not BM818 — different tools
  services.modemmanager.enable = true;

  nixpkgs.config.allowUnfree = true;
}
```

### 5. Desktop variants

| Variant | Phone | Devkit |
|---------|-------|--------|
| **Phosh** | Primary | Possible (via HDMI) |
| **GNOME** | Possible (small screen) | Yes |
| **Plasma Mobile** | Possible | Possible |

For the phone, Phosh is the natural DE. The existing `phosh.nix` needs
adjustment because it references `(import ./secrets.nix).username` (same
issue as PinePhonePro — fixed by the settings split plan).

### 6. Flake additions

```nix
nixosConfigurations.Librem5 = imxConfig "x86_64-linux" ./devices/librem5.nix ./phosh.nix;
nixosConfigurations.Librem5-devkit = imxConfig "x86_64-linux" ./devices/librem5-devkit.nix ./phosh.nix;

packages.image-librem5 = (imxConfig system ./devices/librem5.nix ./phosh.nix).config.system.build.sdImage;
packages.image-librem5-devkit = (imxConfig system ./devices/librem5-devkit.nix ./phosh.nix).config.system.build.sdImage;

checks.Librem5-phosh = mkCheck "Librem5" ./devices/librem5.nix ./phosh.nix "phosh";
checks.Librem5-devkit-phosh = mkCheck "Librem5-devkit" ./devices/librem5-devkit.nix ./phosh.nix "phosh";
```

### 7. Bootstrap / flashing

The Librem 5 uses **Jumpdrive** (a bootable SD image that exposes the phone's
eMMC as a USB mass storage device). The install flow is:

1. Download Jumpdrive image, write to SD
2. Boot phone from SD (insert SD + power on)
3. Phone appears as USB mass storage on host
4. Partition eMMC and flash NixOS SD image
5. Remove SD, reboot

Alternatively, use **uuu** (NXP's Universal Update Utility) with the phone
in serial download mode (hold Vol+ during boot).

### 8. Check assertions

Add `device == "Librem5"` and `device == "Librem5-devkit"` branches to
`mkCheck`:

- `hostName`: `"Librem5"` / `"Librem5Devkit"`
- iio sensor: disabled (no iio on i.MX8M)
- No `landscape.service`
- No `extraHwdb` ACCEL_MOUNT_MATRIX
- `system.stateVersion`: `"25.11"`

---

## Implementation phases

| Phase | What | Files |
|-------|------|-------|
| **1** | Add `nixos-hardware` flake input | `flake.nix` |
| **2** | Create `imxConfig` function for i.MX systems | `flake.nix` |
| **3** | Create device module for phone | `devices/librem5.nix` |
| **4** | Create device module for devkit | `devices/librem5-devkit.nix` |
| **5** | Add nixosConfigurations + eval check | `flake.nix` |
| **6** | Add SD image packages + checks | `flake.nix` |
| **7** | Update `phosh.nix` to not hardcode username import (blocked on settings split) | `phosh.nix` |
| **8** | Build image + test flash + test on hardware | shell |

---

## Risks and open questions

| Risk | Impact | Mitigation |
|------|--------|------------|
| nixos-hardware module may drift from upstream kernel | Kernel or U-Boot build breaks | Pin nixos-hardware revision; test before updating |
| Two WiFi variants (Redpine vs SparkLAN) | Config complexity | `hardware.librem5.wifiCard` option handles this |
| Phosh on phone needs correct touch/rotation | Bad UX out of box | Upstream phosh config supports Librem 5 natively |
| Redpine WiFi is out-of-tree | No WiFi on mainline kernel | nixos-hardware packages the Redpine driver; this is pre-solved |
| Devkit has different modem (SIMCom vs BM818) | Modem config differs | Devkit can use standard ModemManager |
| Cross-compilation from x86_64 to i.MX8M | Build failures | i.MX support in nixpkgs is mature; test early |
