# Plan: add PinePhone Pro support

## Device overview

| Property | Value |
|----------|-------|
| SoC | Rockchip RK3399S (custom RK3399 variant) |
| CPU | 2× Cortex-A72 + 4× Cortex-A53 |
| GPU | Mali-T860 MP4 |
| RAM | 4 GB LPDDR4 |
| Storage | 128 GB eMMC + microSD |
| Display | 6″ 720×1440 IPS (portrait native) |
| Modem | Quectel EG25-G (LTE, GPS, GNSS) |
| WiFi/BT | AMPAK AP6255 (BCM4334 compatible) |
| Sensors | Accelerometer, gyroscope, ALS, proximity, compass |
| Battery | 3000 mAh, Samsung J7 form-factor |
| USB-C | USB 3.0 with DisplayPort alt mode |
| Buttons | Vol up/down, power |
| Kill switches | LTE/GNSS, WiFi/BT, mic, speaker, cameras |

**Status**: Discontinued Aug 2025, but still relevant as an open hardware
reference phone. Same SoC family (RK3399) as PineBookPro.

## What reuses existing infrastructure

| Component | Source | Notes |
|-----------|--------|-------|
| **Kernel** | `rockchip.legacyPackages.kernel_linux_latest_rockchip_stable` | Same RK3399 kernel as PineBookPro; needs DT for PPP |
| **u-boot** | `rockchip.packages.uBootPinebookPro` (or new PPP entry) | May need separate u-boot config for the phone form factor |
| **Cross-compilation** | Existing `osConfig` / `installerConfig` functions | No change needed |
| **Home-manager** | Existing `config.nix` + `home.nix` | Reusable directly |
| **Phosh desktop** | Existing `phosh.nix` | Needs adjustment for phone-specific config |
| **Cachix cache** | `nabam-nixos-rockchip.cachix.org` | Already configured |

## What needs new work

### 1. Device module — `devices/pinephonepro.nix`

```nix
{ lib, pkgs, config, rockchip, buildPlatform, ... }: {
  networking.hostName = "PinePhonePro";
  rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootPinePhonePro;  # TBD
  boot.kernelPackages = rockchip.legacyPackages.${buildPlatform}.kernel_linux_latest_rockchip_stable;
  hardware.firmware = [ rockchip.packages.${buildPlatform}.brcm43456 ];  # or similar
  nixpkgs.config.allowUnfree = true;
  hardware.sensor.iio.enable = true;
}
```

**Open questions**:
- Does `nabam/nixos-rockchip` provide PinePhone Pro u-boot and kernel packages?
  If not, may need to use `mobile-nixos` (<https://github.com/mobile-nixos/mobile-nixos>)
  or package them manually.
- What device tree file does the PPP use? The RK3399S may need a specific DT.

### 2. Modem configuration

The EG25-G modem requires:
- `services.pppd.enable` or ModemManager (`services.modemmanager.enable`)
- `hardware.simlock` or manual AT config
- GPS support via the same modem (gpsd or ModemManager location)
- Audio routing for VoIP calls (PulseAudio/WirePlumber profile)

### 3. Phone-specific services

- `powerManagement` — battery monitoring, suspend-on-lid-close → sleep-on-power-button
- `services.phone-utils` — dialer, SMS (may be DE-specific)
- Kill switch daemon — GPIO toggles for LTE/WiFi/mic/camera
- Vibration motor / notification LED
- Proximity sensor (screen off during call)

### 4. Display / rotation

- Native portrait 720×1440, different from the landscape panels of
  PineBookPro/PineTab2
- ACCEL_MOUNT_MATRIX will differ from existing devices
- Phosh expects portrait by default, but the matrix needs calibration

### 5. Desktop variants

| Variant | Priority | Notes |
|---------|----------|-------|
| **Phosh** | Primary | Phone-optimized; reuses `phosh.nix` with tweaks |
| **Plasma Mobile** | Secondary | Different from existing `plasma.nix` (desktop Plasma 6) |
| **GNOME** | Low | Desktop GNOME is awkward on a phone |

### 6. Flake additions (`flake.nix`)

```nix
nixosConfigurations.PinePhonePro = osConfig "x86_64-linux" ./devices/pinephonepro.nix ./phosh.nix;

packages.image-pinephonepro = (osConfig system ./devices/pinephonepro.nix ./phosh.nix).config.system.build.sdImage;
packages.uboot-pinephonepro = (osConfig system ./devices/pinephonepro.nix { }).config.rockchip.uBoot;
packages.image-installer-pinephonepro = (installerConfig system ./devices/pinephonepro.nix).config.system.build.sdImage;

checks.PinePhonePro-phosh = mkCheck "PinePhonePro" ./devices/pinephonepro.nix ./phosh.nix "phosh";
```

### 7. Check assertions

Add `device == "PinePhonePro"` branches to `mkCheck`:
- iio sensor: enabled (like PineTab2)
- No landscape.service (not a keyboard dock device)
- ACCEL_MOUNT_MATRIX: specific to PPP sensor
- hostName: "PinePhonePro"

## Alternative: mobile-nixos

If `nabam/nixos-rockchip` doesn't support PinePhone Pro well, consider
adding `mobile-nixos` as a flake input instead. mobile-nixos specifically
targets phones (including the PPP) and provides:
- Working u-boot + kernel for PPP
- ModemManager + audio routing
- Power management
- Sxmo/Phosh/Plasma Mobile integrations

However, mobile-nixos has its own build infrastructure that would need to
be reconciled with the existing `osConfig` / `rockchip.nixosModules.sdImageRockchip`
approach used here. This is a larger refactor.

## Recommended approach (phased)

| Phase | What |
|-------|------|
| **1** | Investigate nabam/nixos-rockchip PPP support. Probe `nix eval github:nabam/nixos-rockchip#legacyPackages.x86_64-linux --apply 'x: builtins.attrNames x'` for u-boot/kernel variants. |
| **2** | Create `devices/pinephonepro.nix` with DT, kernel, u-boot, firmware. |
| **3** | Add basic `nixosConfigurations.PinePhonePro` and verify evaluation with `nix flake check --no-build`. |
| **4** | Add modem, power management, sensor config as separate commits. |
| **5** | Add SD image package + installer + checks. |
| **6** | Test on real hardware. |
