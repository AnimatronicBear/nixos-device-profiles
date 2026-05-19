# Plan: add Orange Pi 5 Ultra support

## Device overview

| Property | Value |
|----------|-------|
| SoC | Rockchip RK3588 (8 nm LP) |
| CPU | 4× Cortex-A76 @ 2.4 GHz + 4× Cortex-A55 @ 1.8 GHz |
| GPU | Mali-G610 MP4 (OpenGL ES 3.2, Vulkan 1.2, OpenCL 2.2) |
| NPU | 6 TOPS (INT4/INT8/INT16/FP16) |
| RAM | LPDDR5 — 4 / 8 / 16 GB |
| Storage | eMMC socket OR onboard eMMC, microSD, 16 MB SPI NOR, M.2 NVMe |
| Display | 1× HDMI 2.1 out (8K@60), 1× MIPI DSI |
| Video in | 1× HDMI 2.0 in (4K@60), 2× MIPI CSI |
| Ethernet | 2.5 GbE (Realtek RTL8125BG via PCIe) |
| WiFi/BT | AP6611: Wi-Fi 6E (SDIO3.0) + BT 5.3 (UART/PCM) |
| USB | 2× USB 3.0 (one OTG), 2× USB 2.0 |
| Audio | ES8388 codec, 3.5 mm jack + mic, onboard mic, HDMI eARC |
| Expansion | 40-pin GPIO (UART, PWM, I2C, SPI, CAN, GPIO) |
| Power | USB Type-C, 5 V @ 5 A |

**Mainline status**: Device tree merged in Linux 6.15 (Feb 2025).
U-Boot defconfig (`orangepi-5-ultra-rk3588`) merged in mainline U-Boot.

---

## Key differences from existing devices

| Aspect | PineBookPro / PineTab2 / PinePhonePro | Orange Pi 5 Ultra |
|--------|---------------------------------------|-------------------|
| **SoC family** | RK3399 / RK3566 / RK3399S | RK3588 |
| **Kernel source** | `nabam/nixos-rockchip` custom kernel | Mainline (6.15+) or vendor kernel |
| **GPU** | Mali-T860 / Mali-G52 | Mali-G610 (Valhall) |
| **RAM** | 4 GB LPDDR4 | Up to 16 GB LPDDR5 |
| **PCIe** | None / PCIe 2.0 x1 | PCIe 3.0 x4 (NVMe) |
| **Display** | Single DSI panel or eDP | HDMI 2.1 + MIPI DSI |
| **Form factor** | Laptop / tablet / phone | Single-board computer |
| **Video capture** | None | HDMI 2.0 in, 2× MIPI CSI |
| **Ethernet** | None | 2.5 GbE |
| **WiFi** | bes2600 / brcm43456 | AP6611 (Wi-Fi 6E) |

---

## Recommendation: new flake input for RK3588

The Orange Pi 5 Ultra uses a fundamentally different SoC family (RK3588)
than the existing devices (RK3399/RK3566). `nabam/nixos-rockchip` does
not support any RK3588 boards. Using it would require packaging an entirely
new kernel and u-boot anyway.

**Recommended**: add `gnull/nixos-rk3588` as a flake input instead of
(or alongside) `nabam/nixos-rockchip` for RK3588-based builds.

### Comparison of RK3588 flake options

| Option | Pros | Cons |
|--------|------|------|
| **`gnull/nixos-rk3588`** | Actively maintained; supports OPi 5, 5 Plus, Rock 5A; provides kernel + u-boot + SD image builder; uses standard NixOS modules | Does not include OPi 5 Ultra yet (needs adding DT + defconfig) |
| **`ryan4yin/nixos-rk3588`** | Historical reference | **Archived** — no longer maintained |
| **nixpkgs `linuxPackages_rk3588`** | Upstream kernel; no external flake needed | RK3588 u-boot packages in nixpkgs may not include the Ultra board; less tailored SD image tooling |
| **Custom kernel + u-boot derivations** | Full control | Significantly more work; reinventing what flakes already do |

### Chosen approach

Adopt `gnull/nixos-rk3588` (maintained fork of the archived `ryan4yin/nixos-rk3588`).
It provides:

- Custom kernel (vendor fork based on linux 6.1.y with RK3588 patches)
- Mainline kernel option
- U-boot with RK3588 board support
- SD card / eMMC image builder via `rk3588Console` / `rk3588Desktop` modules
- PCIe, HDMI, USB, NPU enablement
- Mali G610 GPU firmware + Panfrost driver support

This is the closest analogue to what `nabam/nixos-rockchip` provides for
RK3399/RK3566 — a tailored flake with kernel, u-boot, and image generation.

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
  rk3588 = {
    url = "github:gnull/nixos-rk3588";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # ... utils, home-manager unchanged
};
```

### 2. Add RK3588-specific config function — `flake.nix`

```nix
rk3588Config = deviceModule: variant:
  nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit rk3588; };
    modules = [
      { nixpkgs.hostPlatform = "aarch64-linux"; }
      { nixpkgs.buildPlatform = buildPlatform; }
      rk3588.nixosModules.rk3588Console  # or rk3588Desktop with GPU
      rk3588.nixosModules.noZFS
      home-manager.nixosModules.home-manager
      ./config.nix
      variant
      deviceModule
    ];
  };
```

Note: The Rockchip 3588 SoC is aarch64-only, and we cannot cross-compile
from x86_64 easily (the vendor kernel has issues with cross-compilation).
**Initial builds will need to run natively on an aarch64 builder** (e.g.,
a PineBookPro or a QEMU VM), or use `--build-host` with an aarch64 remote.

However, `gnull/nixos-rk3588` may support cross-compilation for mainline
kernel. This needs investigation.

### 3. Device module — `devices/orangepi5ultra.nix`

```nix
{ lib, pkgs, config, rk3588, ... }: {
  networking.hostName = "OrangePi5Ultra";
  rk3588.uBoot = rk3588.packages.aarch64-linux.uBootOrangePi5Ultra;
  boot.kernelPackages = rk3588.legacyPackages.aarch64-linux.kernel;
  hardware.firmware = [ rk3588.packages.aarch64-linux.ap6611-firmware ];
  nixpkgs.config.allowUnfree = true;

  # 2.5 GbE
  boot.kernelModules = [ "r8125" ];

  # Mali-G610 GPU
  hardware.opengl = {
    enable = true;
    extraPackages = [ pkgs.mesa.drivers pkgs.mali-firmware ];
  };

  # HDMI output
  services.xserver.enable = true;  # or wayland

  # NVMe
  boot.initrd.kernelModules = [ "nvme" ];
}
```

### 4. Firmware package

The AP6611 WiFi/BT firmware needs packaging if not already provided by
the rk3588 flake. Same for the Realtek RTL8125 Ethernet driver (r8125
out-of-tree module or in-kernel).

### 5. Desktop variants

| Variant | Notes |
|---------|-------|
| **GNOME** | Standard desktop; HDMI 2.1 capable of 8K |
| **Plasma 6** | Same as existing `plasma.nix` |
| **Headless** | Server/NAS config (no GPU, no DE) |

The existing `gnome.nix`, `plasma.nix`, and `config.nix` can be reused
directly since they don't depend on rockchip-specific options.

### 6. Flake additions

```nix
nixosConfigurations.OrangePi5Ultra = rk3588Config "aarch64-linux" ./devices/orangepi5ultra.nix ./gnome.nix;

packages.image-orangepi5ultra = (rk3588Config "aarch64-linux" ./devices/orangepi5ultra.nix ./gnome.nix).config.system.build.sdImage;

formatter = pkgs.nixfmt-tree;
```

### 7. Check assertions

Add `device == "OrangePi5Ultra"` branches to `mkCheck`:
- `hostName`: `"OrangePi5Ultra"`
- iio sensor: disabled (no accelerometer on this board)
- No `landscape.service`
- No `extraHwdb` ACCEL_MOUNT_MATRIX
- `system.stateVersion`: `"25.11"`

### 8. Image-specific considerations

The Orange Pi 5 Ultra boots differently from Pine devices:
- SPI flash can store u-boot (16 MB)
- Boot order: SPI → eMMC → SD → NVMe (configurable)
- SD image must use Rockchip boot partition layout (idbloader + u-boot)
- The `rk3588.nixosModules.rk3588Console` module handles this

---

## Implementation phases

| Phase | What | Files |
|-------|------|-------|
| **1** | Add `gnull/nixos-rk3588` flake input, create `rk3588Config` function | `flake.nix` |
| **2** | Create device module with kernel, u-boot, firmware | `devices/orangepi5ultra.nix` |
| **3** | Add basic `nixosConfigurations.OrangePi5Ultra`, verify eval | `flake.nix` |
| **4** | Add SD image package + check assertions | `flake.nix` |
| **5** | Add GPU enablement + desktop variant | `devices/orangepi5ultra.nix` |
| **6** | Add 2.5 GbE, NVMe, USB3 | `devices/orangepi5ultra.nix` |
| **7** | Build image + test on hardware | shell |

---

## Risks and open questions

| Risk | Impact | Mitigation |
|------|--------|------------|
| Cross-compilation from x86_64 doesn't work with RK3588 vendor kernel | Requires aarch64 builder (QEMU, remote, or native) | Test mainline kernel cross-compile first; accept native builds if needed |
| `gnull/nixos-rk3588` doesn't include Orange Pi 5 Ultra u-boot | Must package u-boot defconfig + DTS ourselves | Easy — u-boot defconfig is mainlined; add as overlay |
| AP6611 WiFi not yet working on mainline Linux | No WiFi on mainline kernel | Use vendor kernel from rk3588 flake or wait for mainline support |
| HDMI RX (video capture) has immature drivers | HDMI input may not work | Accept as known limitation; document as TODO |
| Mali G610 firmware licensing | Unfree firmware needed | Already handled by `nixpkgs.config.allowUnfree` |
| RK3588 NPU not supported in mainline | NPU unavailable | Upstream driver (rocket) still in development; accept limitation |

---

## Prior art: other NixOS RK3588 projects

- **`ryan4yin/nixos-rk3588`** (archived) — original RK3588 NixOS flake,
  supported OPi 5, 5 Plus, Rock 5A, CM5. Superseded by gnull.
- **`gnull/nixos-rk3588`** — maintained fork. Provides kernel 6.1.y vendor +
  mainline 6.x, u-boot, Mali firmware, image builder. The closest analogue
  to `nabam/nixos-rockchip` for RK3588.
- **NixOS wiki RK3588 page** — documents manual kernel configuration for
  generic RK3588. Recommends `gnull/nixos-rk3588` for new users.
- **Armbian** — uses vendor kernel (6.1.y with RK3588 fork) + mainline edge
  kernel (6.15+). Mainline boots successfully per PR #8252.
