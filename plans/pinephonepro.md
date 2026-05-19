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
| WiFi/BT | AMPAK AP6255 |
| Sensors | Accelerometer, gyroscope, ALS, proximity, compass |
| Battery | 3000 mAh, Samsung J7 form-factor |
| USB-C | USB 3.0 with DisplayPort alt mode |
| Buttons | Vol up/down, power |
| Kill switches | LTE/GNSS, WiFi/BT, mic, speaker, cameras |

**Status**: Discontinued Aug 2025. Same SoC family (RK3399S) as PineBookPro (RK3399).

---

## Recommendation

**Neither nixos-hardware nor mobile-nixos should be added as flake inputs.**

| Repo | Verdict | Reason |
|------|---------|--------|
| **nixos-hardware** | Skip | PineBookPro profile offers only initrd kernel modules + wifi.powersave — already handled manually. No PinePhonePro or PineTab2 support at all. |
| **mobile-nixos** | Cherry-pick only | Full PinePhonePro device support, but built on a completely different infrastructure (`mobile.*` options, custom kernel builder, own SD image pipeline). Incompatible with `nabam/nixos-rockchip`. The kernel is stuck at v6.4.7. |

For PinePhone Pro, cherry-pick specific components (kernel DT, firmware,
modem service, ALSA UCM profiles) into our existing nixos-rockchip pipeline
rather than adopting either repo wholesale.

---

## What reuses existing infrastructure

| Component | Source | Notes |
|-----------|--------|-------|
| **Cross-compilation** | Existing `osConfig` / `installerConfig` functions | Identical structure |
| **Home-manager** | Existing `config.nix` + `home.nix` | Reusable directly |
| **Phosh desktop** | Existing `phosh.nix` | Needs minor tweaks (phone user, no XWayland workaround) |
| **Cachix cache** | `nabam-nixos-rockchip.cachix.org` | Already configured |
| **Kernel** | `rockchip.legacyPackages.kernel_linux_latest_rockchip_stable` | Same RK3399 kernel, but may lack the specific PPP device tree (rk3399-pinephone-pro.dtb) |

---

## What needs new work

### 1. Kernel and device tree

The main unknown: does `nabam/nixos-rockchip`'s RK3399 kernel package include
the PinePhone Pro device tree? If yes, no custom kernel needed. If not, three
alternatives:

| Source | Pros | Cons |
|--------|------|------|
| **megi's kernel fork** (<https://github.com/megi/linux>) | Actively maintained, used by Manjaro/Arch ARM | Needs packaging as a nixpkgs derivation |
| **mobile-nixos kernel** (v6.4.7) | Known-working DT patches | Very old; patches extracted from mobile-nixos |
| **Package DT only** | Extract rk3399-pinephone-pro.dtb + overlays from any source | Minimal maintenance; couples to kernel ABI |

Recommended: package a recent megi kernel with a custom overlay in
`pkgs/kernel-pinephonepro/default.nix`.

### 2. Device module — `devices/pinephonepro.nix`

```nix
{ lib, pkgs, config, rockchip, buildPlatform, ... }: {
  networking.hostName = "PinePhonePro";
  rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootPinephonePro;
  boot.kernelPackages = /* custom or from rockchip flake — TBD */;
  hardware.firmware = [ /* AP6256 firmware package */ ];
  nixpkgs.config.allowUnfree = true;
  hardware.sensor.iio.enable = true;
  networking.networkmanager.wifi.powersave = false;

  # Phone-specific services
  services.eg25-manager.enable = true;         # LTE modem (nixpkgs)
  services.udev.extraHwdb = ''                 # ACCEL_MOUNT_MATRIX
    sensor:modalias:*:*
      ACCEL_MOUNT_MATRIX=1, 0, 0; 0, 1, 0; 0, 0, 1
  '';

  # Kill switch GPIO handling
  systemd.services.killswitch-daemon = {
    description = "PinePhone Pro kill switch monitor";
    wantedBy = [ "multi-user.target" ];
    script = /* monitor GPIOs for LTE/WiFi/mic/camera */;
  };
}
```

### 3. Firmware package — `pkgs/ap6256-firmware/default.nix`

Reference mobile-nixos firmware derivation. Packages AP6256 WiFi/BT firmware
and Rockchip DPTX firmware from Manjaro GitLab + linux-firmware.

### 4. Modem (EG25-G)

The Quectel EG25-G modem is supported in nixpkgs via:
- `services.eg25-manager.enable` — power management, network interface
- ModemManager detects it automatically for SMS/data/calls
- GPS: `services.gpsd.enable` with the modem's GPS NMEA port
- ALSA UCM profiles: needed for audio routing through the modem
  (can reference mobile-nixos `pkgs.mobile-nixos.pine64-alsa-ucm`)

### 5. USB gadget mode

For RNDIS networking, mass storage, and ADB when connected via USB:
- `services.usbgadget.enable` or manual configFS setup
- Reference: mobile-nixos uses `gadgetfs` with RNDIS + mass storage + ADB
- Useful for headless setup and debugging

### 6. Phone-specific features

| Feature | Approach |
|---------|----------|
| Battery monitoring | `powerManagement` / upower with CW2015 fuel gauge |
| Sleep on power button | systemd-logind `HandlePowerKey=suspend` |
| Proximity sensor | iio-sensor-proxy (handled by `hardware.sensor.iio`) |
| Vibration motor | GPIO vibrator via `INPUT_GPIO_VIBRA` (kernel config) |
| Notification LED | LED trigger sysfs |
| Camera | STK3310 sensor; camera firmware from linux-firmware |

### 7. Desktop variants

| Variant | Priority | Notes |
|---------|----------|-------|
| **Phosh** | Primary | Phone-optimized; reuses `phosh.nix` with user fix |
| **Plasma Mobile** | Secondary | Different from existing `plasma.nix` (desktop Plasma 6) — new file needed |
| **GNOME** | Low | Desktop GNOME is awkward on a phone |

The existing `phosh.nix` references `(import ./secrets.nix).username` for the
phosh user. This will be fixed by the settings split (see `settings-split.md`).

### 8. Flake additions

```nix
nixosConfigurations.PinePhonePro = osConfig "x86_64-linux" ./devices/pinephonepro.nix ./phosh.nix;

packages.image-pinephonepro = (osConfig system ./devices/pinephonepro.nix ./phosh.nix).config.system.build.sdImage;
packages.uboot-pinephonepro = (osConfig system ./devices/pinephonepro.nix { }).config.rockchip.uBoot;
packages.image-installer-pinephonepro = (installerConfig system ./devices/pinephonepro.nix).config.system.build.sdImage;

checks.PinePhonePro-phosh = mkCheck "PinePhonePro" ./devices/pinephonepro.nix ./phosh.nix "phosh";
```

### 9. Check assertions

Add `device == "PinePhonePro"` branches to `mkCheck`:
- `hostName`: `"PinePhonePro"`
- iio sensor: enabled (like PineTab2)
- No `landscape.service` (not a keyboard dock device)
- ACCEL_MOUNT_MATRIX present and matches PPP sensor orientation
- `services.eg25-manager.enable` is true

---

## Implementation phases

| Phase | What | Files |
|-------|------|-------|
| **1** | Probe `nabam/nixos-rockchip` for existing PPP support | (shell only) |
| **2** | Package kernel (megi fork) + AP6256 firmware | `pkgs/kernel-pinephonepro/`, `pkgs/ap6256-firmware/` |
| **3** | Create device module | `devices/pinephonepro.nix` |
| **4** | Add nixosConfigurations + eval check | `flake.nix` |
| **5** | Add modem + ALSA UCM | `devices/pinephonepro.nix` + `pkgs/alsa-ucm-pinephonepro/` |
| **6** | Add USB gadget + battery + kill switches | `devices/pinephonepro.nix` |
| **7** | Add SD image + installer + flake checks | `flake.nix` |
| **8** | Build image + test on hardware | shell |

---

## nixos-hardware analysis (for reference)

The `pine64/pinebook-pro` module in nixos-hardware provides:

```nix
{
  boot.initrd.kernelModules = [ /* rockchip DRM, GPU, USB-C, PCIe, battery */ ];
  hardware.enableRedistributableFirmware = true;
  networking.networkmanager.wifi.powersave = false;
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
```

This overlaps with what's already in `devices/pinebook-pro.nix` and `config.nix`.
Adding a flake input for this trivial config is not justified.

## mobile-nixos analysis (for reference)

mobile-nixos `pine64-pinephonepro` (file: `devices/pine64-pinephonepro/default.nix`):

```nix
{
  mobile.device.name = "pine64-pinephonepro";
  mobile.hardware.soc = "rockchip-rk3399s";
  mobile.boot.stage-1.kernel.package = pkgs.callPackage ./kernel { };
  mobile.system.type = "u-boot";
  mobile.usb.mode = "gadgetfs";
  services.eg25-manager.enable = true;
  mobile.quirks.audio.alsa-ucm-meld = true;
  environment.systemPackages = [ pkgs.mobile-nixos.pine64-alsa-ucm ];
}
```

The `mobile.*` options are defined in mobile-nixos' own module system and are
incompatible with `nabam/nixos-rockchip`. The kernel (v6.4.7, monolithic) is
packaged via their custom `mobile-nixos.kernel-builder`. Neither the module
system nor the kernel builder can be reused without adopting the entire
mobile-nixos framework.

**What can be cherry-picked from mobile-nixos**:
- Device tree patches (`0001-arm64-dts-rockchip-*.patch`) — these are the
  most valuable artifacts
- ALSA UCM profile package (`pkgs.mobile-nixos.pine64-alsa-ucm`)
- Firmware derivation structure (AP6256 + BRCM + rockchip DPTX)
- EG25-G modem integration pattern (`services.eg25-manager.enable`)
- USB gadget config (`gadgetfs` with RNDIS + mass storage + ADB)
