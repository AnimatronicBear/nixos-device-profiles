# Plan: add Pine64 RockPro64 support

## Device overview

| Property | Value |
|----------|-------|
| SoC | Rockchip RK3399 (same as PineBookPro) |
| CPU | 2× Cortex-A72 @ 1.8 GHz + 4× Cortex-A53 @ 1.4 GHz |
| GPU | Mali-T860 MP4 (panfrost) |
| RAM | 2 or 4 GB LPDDR4 |
| Storage | microSD, optional eMMC module (up to 128 GB), 128 Mbit SPI NOR |
| PCIe | PCIe x4 slot (Gen1 only — Rockchip errata) |
| Ethernet | Gigabit Ethernet (RTL8211E/F via GMAC) |
| USB | 1× USB 3.0 Type-A, 1× USB 3.0 Type-C (with DP 1.2), 2× USB 2.0 |
| HDMI | 4K HDMI out, DP 1.2 over USB-C |
| Display | Also eDP and MIPI DSI connectors |
| Audio | 3.5 mm headphone+mic jack (ES8316 codec), SPDIF |
| GPIO | 40-pin Pi-2 header |
| WiFi/BT | Optional SDIO module (AP6354 etc.) — **not populated by default** |
| Power | 12 V barrel jack (3–5 A) |
| Mainline DT | `rk3399-rockpro64.dts` (fully upstream) |
| U-Boot | `rockpro64-rk3399_defconfig` (fully upstream) |

---

## Key difference from PineBookPro

| Aspect | PineBookPro | RockPro64 |
|--------|-------------|-----------|
| **Form factor** | Laptop (keyboard, battery, display, trackpad) | Single-board computer |
| **Ethernet** | None | Gigabit Ethernet (needs `ethtool -K rx off tx off`) |
| **PCIe** | None | PCIe x4 slot (NVMe SSDs, GPUs, etc.) |
| **WiFi** | brcmfmac (onboard) | Optional SDIO module, not included |
| **Display** | eDP panel (1366×768) | HDMI + DP + MIPI DSI + eDP connectors |
| **Battery** | 10,000 mAh | None (barrel jack power) |
| **Sensors** | None | No IIO sensors |
| **Fan** | None | PWM fan header (needs fancontrol) |
| **U-Boot flash** | `seek=32768` (SPI) | `seek=64` + `seek=16384` (SD/eMMC) |

---

## Reusability

Almost everything from the existing project can be reused directly:

| Component | Reuse | Change needed |
|-----------|-------|---------------|
| **`nabam/nixos-rockchip` flake** | Full | Already provides `uBootRockPro64` + same kernel |
| **`kernel_linux_latest_rockchip_stable`** | Full | Same kernel as PineBookPro |
| **`config.nix`** | Mostly | Remove WiFi profile (no built-in WiFi); add Ethernet workaround |
| **`gnome.nix` / `plasma.nix` / `phosh.nix`** | Full | Deskops work identically on RK3399 |
| **Home-manager** | Full | `home.nix` is reusable |
| **Checks framework** | Full | Same `mkCheck` pattern |
| **Cross-compilation** | Full | Same `osConfig` / `installerConfig` |

---

## Changes required

### 1. Device module — `devices/rockpro64.nix`

Minimal, modeled on `pinebook-pro.nix`:

```nix
{ lib, pkgs, config, rockchip, buildPlatform, ... }: {
  networking.hostName = "RockPro64";
  rockchip.uBoot = rockchip.packages.${buildPlatform}.uBootRockPro64;
  boot.kernelPackages = rockchip.legacyPackages.${buildPlatform}.kernel_linux_latest_rockchip_stable;
  nixpkgs.config.allowUnfree = true;

  # Ethernet checksum offload is broken on this board
  networking.localCommands = ''
    ${pkgs.ethtool}/bin/ethtool -K eth0 rx off tx off
  '';

  # PCIe NVMe support (optional, but common)
  boot.initrd.kernelModules = [ "nvme" ];
}
```

### 2. Add flake entries — `flake.nix`

```nix
nixosConfigurations.RockPro64 = osConfig "x86_64-linux" ./devices/rockpro64.nix ./gnome.nix;
nixosConfigurations.RockPro64-plasma = osConfig "x86_64-linux" ./devices/rockpro64.nix ./plasma.nix;

packages.image-rockpro64 = (osConfig system ./devices/rockpro64.nix ./gnome.nix).config.system.build.sdImage;
packages.uboot-rockpro64 = (osConfig system ./devices/rockpro64.nix { }).config.rockchip.uBoot;
packages.image-installer-rockpro64 = (installerConfig system ./devices/rockpro64.nix).config.system.build.sdImage;

checks.RockPro64-gnome = mkCheck "RockPro64" ./devices/rockpro64.nix ./gnome.nix "gnome";
checks.RockPro64-plasma = mkCheck "RockPro64" ./devices/rockpro64.nix ./plasma.nix "plasma";
```

### 3. Check assertions

Add `device == "RockPro64"` branches to `mkCheck`:
- `hostName`: `"RockPro64"`
- iio sensor: disabled (no accelerometer)
- No `landscape.service`
- No `extraHwdb` ACCEL_MOUNT_MATRIX
- `system.stateVersion`: `"25.11"`

### 4. Flashing u-boot to SD (for reference)

Unlike PineBookPro (SPI flash), RockPro64 typically uses SD/eMMC boot:

```shell
# Write idbloader at sector 64, u-boot.itb at sector 16384
dd if=idbloader.img of=/dev/sdX conv=fsync,notrunc bs=512 seek=64
dd if=u-boot.itb of=/dev/sdX conv=fsync,notrunc bs=512 seek=16384
```

The SD image from `config.system.build.sdImage` handles this automatically
via `nabam/nixos-rockchip`'s image builder.

### 5. Tow-Boot alternative (SPI flash)

The nixos-hardware profile recommends flashing **Tow-Boot** to SPI flash
for a more robust bootloader that supports UEFI. This is optional — the
nabam nixos-rockchip u-boot works too.

---

## Implementation phases

| Phase | What | Files |
|-------|------|-------|
| **1** | Create device module with Ethernet workaround | `devices/rockpro64.nix` |
| **2** | Add nixosConfigurations + eval check to flake | `flake.nix` |
| **3** | Add SD image packages + installer + u-boot | `flake.nix` |
| **4** | Add check assertions | `flake.nix` (in `mkCheck`) |
| **5** | Build image + test | shell |

No new flake inputs, no custom kernels, no infrastructure changes.
The RockPro64 is the simplest addition — same SoC, same kernel, same
image builder, same desktop configs. Just Ethernet quirk + minimal
device module.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Ethernet checksum offload not disabled | Network instability/corruption | `networking.localCommands` with ethtool handles it |
| PCIe NVMe not detected at boot | No root-on-NVMe | `boot.initrd.kernelModules = [ "nvme" ]` |
| nixos-rockchip `uBootRockPro64` is "untested" | May not boot | Fall back to nixpkgs `ubootRockPro64` or Tow-Boot |
| Optional WiFi module not handled | No WiFi if module is present | User adds firmware manually if they have a module |
