# Plan: add Raspberry Pi 4 Model B support

## Device overview

| Property | Value |
|----------|-------|
| SoC | Broadcom BCM2711 (4× Cortex-A72 @ 1.5 GHz) |
| GPU | VideoCore VI @ 500 MHz (V3D/V3DV — OpenGL ES 3.1, Vulkan 1.3) |
| RAM | 1, 2, 4, or 8 GB LPDDR4-3200 |
| Storage | microSD, USB boot |
| Ethernet | Gigabit Ethernet (separate from USB) |
| WiFi/BT | BCM43455 — 2.4/5 GHz 802.11ac + BT 5.0 |
| USB | 2× USB 3.0, 2× USB 2.0 |
| Video | 2× micro-HDMI (up to 4Kp60 each), MIPI DSI |
| Audio | HDMI audio, 4-pole composite, I2S |
| GPIO | 40-pin header |
| Power | 5 V USB-C (min 3 A), PoE (via HAT) |
| Mainline DT | `bcm2711-rpi-4-b.dtb` (fully upstream) |

---

## Key difference from Rockchip devices

| Aspect | Rockchip devices (existing) | Raspberry Pi 4 |
|--------|-----------------------------|----------------|
| **SoC** | RK3399 / RK3566 / RK3588 | Broadcom BCM2711 |
| **Boot process** | Rockchip TPL→SPL→ATF→U-Boot | GPU firmware (`start4.elf`) → U-Boot or direct kernel |
| **GPU** | Mali (panfrost) | VideoCore VI (V3D Mesa driver) |
| **GPU boot blob** | None required | `start4.elf` + `fixup4.dat` (proprietary, required) |
| **Kernel** | `nabam/nixos-rockchip` vendor kernel | Raspberry Pi vendor kernel (`linux_rpi`) or mainline |
| **U-Boot** | `nabam/nixos-rockchip` packages | `ubootRaspberryPi4_64bit` from nixpkgs |
| **NixOS SD image** | `sdImageRockchip` from nixos-rockchip | Generic `sdImage` (sd-image-aarch64.nix) |
| **Ubiquity** | Niche hardware | Most popular SBC worldwide |

**Cannot use `nabam/nixos-rockchip`** — no Broadcom support exists there.

---

## External repo analysis

### nixos-hardware (`github:NixOS/nixos-hardware`)

**Full support at `raspberry-pi/4/`** — this is the most comprehensive
nixos-hardware module of any device in this project's plan scope:

| Module | Purpose |
|--------|---------|
| `default.nix` | Main module — imports all submodules, sets kernel, bootloader, firmware, device tree filter |
| `modesetting.nix` | GPU modesetting via `vc4-fkms-v3d` overlay, CMA config, X11 modesetting |
| `audio.nix` | Audio device tree overlay, PulseAudio `tsched=0` |
| `bluetooth.nix` | Bluetooth via UART pin overlay |
| `wifi.nix` | WiFi firmware + configuration |
| `poe-hat.nix` | PoE HAT fan control (4 temp trip points) |
| `poe-plus-hat.nix` | PoE+ HAT support |
| `touch-ft5406.nix` | Official 7" touchscreen |
| `dwc2.nix` | USB gadget/OTG mode |
| `gpio.nix` | GPIO setup |
| `i2c.nix` | I2C bus |
| `leds.nix` | Activity/power LED config |
| `backlight.nix` | Display backlight |
| `cpu-revision.nix` | B0 vs C0 stepping detection |
| `xhci.nix` | USB 3.0 XHCI controller |
| `common/kernel.nix` | Vendor kernel `6.12.75` from `raspberrypi/linux` |
| `common/config-txt.nix` | Nix-based `config.txt` generation |
| `common/raspberry-pi-wireless-firmware.nix` | WiFi/BT firmware blobs |

The kernel is the Raspberry Pi **vendor kernel** (not mainline), at version
6.12.75, using `bcm2711_defconfig`.

### nixpkgs packages

| Package | Purpose |
|---------|---------|
| `ubootRaspberryPi4_64bit` | U-Boot for Pi 4 in 64-bit mode (`rpi_4_defconfig`) |
| `raspberrypi-firmware` | GPU firmware blobs (`start4.elf`, `fixup4.dat`, etc.) |
| `raspberrypi-eeprom` | `rpi-eeprom-update` tool + EEPROM images |
| `libraspberrypi` | Userspace VideoCore libraries (mostly deprecated) |

The generic aarch64 NixOS SD image uses `ubootRaspberryPi4_64bit` + extlinux.

---

## Recommendation: use nixos-hardware as a flake input

Same rationale as the Librem 5 — nixos-hardware provides significant value
that would otherwise need to be packaged from scratch:

| Need | Source |
|------|--------|
| Vendor kernel (6.12.75) with Pi-specific patches | nixos-hardware (`common/kernel.nix`) |
| GPU modesetting (`vc4-fkms-v3d`) | nixos-hardware (`modesetting.nix`) |
| WiFi firmware blobs (proprietary) | nixos-hardware (`wifi.nix` + `common/raspberry-pi-wireless-firmware.nix`) |
| Bluetooth enablement | nixos-hardware (`bluetooth.nix`) |
| Audio config (PulseAudio `tsched=0`) | nixos-hardware (`audio.nix`) |
| USB 3.0 initrd modules (VL805 PCIe) | nixos-hardware (`default.nix`) |
| `config.txt` generation | nixos-hardware (`common/config-txt.nix`) |
| PoE HAT, touchscreen, GPIO, I2C, etc. | nixos-hardware (various submodules) |

Since we're already planning to add `nixos-hardware` for the Librem 5,
the RPi4 can share the same flake input with zero additional overhead.

---

## Changes required

### 1. Add flake input — `flake.nix`

If not already added for the Librem 5:

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

### 2. Add RPi4-specific config function — `flake.nix`

```nix
rpiConfig = deviceModule: variant:
  nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      { nixpkgs.hostPlatform = "aarch64-linux"; }
      { nixpkgs.buildPlatform = buildPlatform; }
      home-manager.nixosModules.home-manager
      nixos-hardware.nixosModules.raspberry-pi-4
      ./config.nix
      variant
      deviceModule
    ];
  };
```

Note: Cross-compilation from x86_64 to aarch64 is well-tested for the RPi4.
nixpkgs has excellent support for ARM cross-compilation.

### 3. Device module — `devices/rpi4.nix`

```nix
{ lib, pkgs, config, ... }: {
  networking.hostName = "RPi4";

  # No iio sensor, no landscape.service, no accel matrix
  # The nixos-hardware module handles everything else

  # User is in docker group, etc. — handled by config.nix

  nixpkgs.config.allowUnfree = true;
}
```

Minimal. The nixos-hardware module handles kernel, GPU, WiFi, Bluetooth,
audio, GPIO, and initrd. Our `config.nix` handles SSH, users, pipewire,
docker, and home-manager.

### 4. Desktop variants

| Variant | Notes |
|---------|-------|
| **GNOME** | Works via V3D Mesa driver; 2× HDMI at 4K |
| **Plasma 6** | Same; works via V3D |
| **Headless** | Server/NAS — no DE needed |

The existing `gnome.nix`, `plasma.nix`, and `config.nix` can be reused
directly since they don't depend on rockchip-specific options.

### 5. Flake additions

```nix
nixosConfigurations.RPi4 = rpiConfig "x86_64-linux" ./devices/rpi4.nix ./gnome.nix;

packages.image-rpi4 = (rpiConfig system ./devices/rpi4.nix ./gnome.nix).config.system.build.sdImage;
packages.image-installer-rpi4 = (installerConfig system ./devices/rpi4.nix).config.system.build.sdImage;

checks.RPi4-gnome = mkCheck "RPi4" ./devices/rpi4.nix ./gnome.nix "gnome";
```

### 6. Check assertions

Add `device == "RPi4"` branches to `mkCheck`:
- `hostName`: `"RPi4"`
- iio sensor: disabled
- No `landscape.service`
- No `extraHwdb` ACCEL_MOUNT_MATRIX
- `system.stateVersion`: `"25.11"`

### 7. Boot and flashing

The RPi4 boot process is different from Rockchip:

1. GPU boots first from SPI EEPROM → loads `start4.elf` + `fixup4.dat` from FAT partition
2. GPU parses `config.txt` on the FAT partition
3. GPU loads U-Boot (`u-boot-rpi-4.bin`, named `kernel8.img` on the FAT partition)
4. U-Boot reads `extlinux/extlinux.conf` → boots NixOS kernel + initrd

The generic aarch64 `sdImage` builder handles this automatically:
- Creates a FAT boot partition with `start4.elf`, `fixup4.dat`, `config.txt`, `u-boot-rpi-4.bin`
- Creates an ext4 root partition

Flashing is simple `dd`:
```shell
dd if=result/sd-image/*.img of=/dev/sdX bs=4M conv=fsync
```

### 8. nixos-hardware module configuration (optional extras)

The nixos-hardware module exposes configuration via `hardware.raspberry-pi.*`
options and `config.txt` generation. Users can customize:

```nix
hardware.raspberry-pi.configtxt.settings = {
  all = {
    gpio = "3=0,2=0,14=1,15=1";
  };
  pi4 = {
    arm_freq = "2000";
    over_voltage = "6";
  };
};
```

---

## Comparison with other plan devices

| Aspect | RockPro64 | RPi4 |
|--------|-----------|------|
| **SoC** | RK3399 | BCM2711 |
| **New flake input needed** | None | `nixos-hardware` (shared with Librem 5) |
| **nixos-hardware value** | Low (fan control + PCIe modules) | **High** (kernel, GPU, WiFi, BT, audio, config.txt) |
| **Device module size** | ~10 lines | ~5 lines |
| **Boot process** | Standard Rockchip | GPU firmware → U-Boot (unique) |
| **Desktop support** | Same as PineBookPro | V3D Vulkan 1.3 |

---

## Implementation phases

| Phase | What | Files |
|-------|------|-------|
| **1** | Add `nixos-hardware` flake input | `flake.nix` |
| **2** | Create `rpiConfig` function | `flake.nix` |
| **3** | Create device module | `devices/rpi4.nix` |
| **4** | Add nixosConfigurations + eval check | `flake.nix` |
| **5** | Add SD image package + checks | `flake.nix` |
| **6** | Build image + test on hardware | shell |

---

## Risks and open questions

| Risk | Impact | Mitigation |
|------|--------|------------|
| nixos-hardware kernel is vendor fork (6.12.75) | May drift from upstream | Pin nixos-hardware revision; same approach as Librem 5 |
| HDMI console appears on wrong port | Debugging frustration | Known quirk — try both HDMI ports |
| USB boot requires EEPROM update | User may have old bootloader | Document `rpi-eeprom-update` in flashing instructions |
| Building on Pi4 with 2 GB RAM | OOM during nix build | Cross-compile from x86_64 (recommended for all devices in this project) |
| `boot.loader.raspberrypi.firmwareConfig` removed in 24.11 | Old docs reference removed option | Use `hardware.raspberry-pi.configtxt.settings` instead |
| No battery/sensor/accel matrix | Check assertions handle this | Trivial — add `device == "RPi4"` branch to mkCheck |
