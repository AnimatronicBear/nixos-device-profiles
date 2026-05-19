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

---

## What reuses existing infrastructure

| Component | Source | Notes |
|-----------|--------|-------|
| **Kernel** | `rockchip.legacyPackages.kernel_linux_latest_rockchip_stable` | Same RK3399 kernel as PineBookPro; needs DT for PPP |
| **u-boot** | `rockchip.packages.uBootPinebookPro` (or new PPP entry) | May need separate u-boot config for the phone form factor |
| **Cross-compilation** | Existing `osConfig` / `installerConfig` functions | No change needed |
| **Home-manager** | Existing `config.nix` + `home.nix` | Reusable directly |
| **Phosh desktop** | Existing `phosh.nix` | Needs adjustment for phone-specific config |
| **Cachix cache** | `nabam-nixos-rockchip.cachix.org` | Already configured |

---

## External repo analysis

### nixos-hardware (`github:NixOS/nixos-hardware`)

**What it has for Pine devices**:
- `pine64/pinebook-pro` — kernel modules overlay for initrd, wifi.powersave fix,
  redistributable firmware flag

**What it's missing**:
- No PinePhone Pro profile
- No PineTab2 profile
- No phone/modem services

**Could we use it?** The pinebook-pro module provides `boot.initrd.kernelModules`
and `networking.networkmanager.wifi.powersave` that could replace some manual
config in `devices/pinebook-pro.nix`. Not worth adding as a dependency for
existing devices (trivial config). For PinePhone Pro, it offers nothing.

### mobile-nixos (`github:mobile-nixos/mobile-nixos`)

**What it has for Pine devices**:
- `pine64-pinephonepro` — **full device support** (kernel, firmware, modem,
  audio, USB gadget, device tree)
- `pine64-pinephone` — original PinePhone
- `pine64-pinetab` — original PineTab (Allwinner A64, **not** PineTab2)

**PinePhone Pro kernel** (`devices/pine64-pinephonepro/kernel/default.nix`):
- Custom kernel v6.4.7 built from `pine64-org/linux` GitLab repo
- Patches: USB role switch, LED defaults, DWC3 OTG
- Installs `rk3399-pinephone-pro.dtb` device tree
- Monolithic (non-modular), not compressed
- Kernel v6.4.7 is quite old (mid-2023) — likely outdated

**PinePhone Pro firmware** (`devices/pine64-pinephonepro/firmware/default.nix`):
- AP6256 WiFi/BT firmware from Manjaro GitLab
- BRCM firmware from xff.cz git
- Pinebook firmware from Manjaro GitLab (for WiFi/BT calibration)
- Rockchip DPTX firmware

**PinePhone Pro config** (`devices/pine64-pinephonepro/default.nix`):
- EG25-G modem via `services.eg25-manager.enable`
- ALSA UCM profiles for audio (`mobile.quirks.audio.alsa-ucm-meld`)
- USB gadget mode (`gadgetfs`) for RNDIS, mass storage, ADB
- Serial console on ttyS2
- Boot config for internal eMMC storage path
- Stage-1 tasks for USB role switching

**Key differences from our project's approach**:
- Uses `mobile.*` NixOS options (custom module system) — not compatible with
  `nixos-rockchip` / `sdImageRockchip` approach
- Has its own kernel builder, initrd system, boot image generation
- Replaces the entire SD image build pipeline rather than layering on top
- Not designed to be mixed with `nabam/nixos-rockchip`

---

## Evaluation and recommendation

| Aspect | nixos-hardware | mobile-nixos |
|--------|---------------|--------------|
| Useful for existing devices? | Trivial overlap only | No (different infra) |
| PinePhone Pro support? | None | Full, but infra mismatch |
| Effort to integrate | Low value | Architectural fork |

**Neither repo should be adopted as a dependency for this project.**

### For existing devices (PineBookPro / PineTab2)

The nixos-hardware pinebook-pro module offers only `boot.initrd.kernelModules`
and `wifi.powersave`. These are already handled manually in the device configs
and `config.nix`. Adding it as a flake input is not worth the dependency.

mobile-nixos doesn't support PineTab2 and uses a different build system.

### For PinePhone Pro

mobile-nixos provides the most complete PinePhone Pro support, but its
infrastructure is fundamentally different from our nixos-rockchip-based
approach. Adopting it would mean either:

1. **Dual-flake approach**: Keep this flake for PinePhonePro (using nixos-rockchip)
   and add a separate `mobile-nixos` flake output for the phone. This means
   maintaining two build pipelines for the same project.

2. **Selective cherry-picking**: Extract the PinePhone Pro kernel config,
   firmware packaging, modem service, and DT patches from mobile-nixos and
   adapt them to the nixos-rockchip `sdImageRockchip` pipeline. The `eg25-manager`
   and ALSA UCM profiles are standard NixOS packages that can be used directly.

3. **Not worth doing**: Given the PinePhone Pro was discontinued in August 2025
   and the kernel from mobile-nixos is stuck at 6.4.7 (mid-2023), the effort
   may exceed the value. The nixos-rockchip upstream would need to add PPP
   support first for a clean integration.

## Recommended approach (cherry-picking from mobile-nixos)

If proceeding despite the challenges, the phased approach is:

| Phase | What |
|-------|------|
| **1** | Investigate `nabam/nixos-rockchip` for any PPP support. Probe: `nix eval github:nabam/nixos-rockchip#legacyPackages.x86_64-linux --apply 'x: builtins.attrNames x'` |
| **2** | Create `devices/pinephonepro.nix` referencing the PinePhone Pro DT from the RK3399 kernel. If nixos-rockchip doesn't provide the DT, package the mobile-nixos kernel's DT output or build megi's kernel fork (<https://github.com/megi/linux>) |
| **3** | Package AP6256 firmware (reference mobile-nixos firmware derivation) |
| **4** | Add basic `nixosConfigurations.PinePhonePro` and verify evaluation |
| **5** | Add EG25-G modem via `services.eg25-manager` (available in nixpkgs) and ALSA UCM profiles from mobile-nixos |
| **6** | Add USB gadget mode (`gadgetfs`), kill switch GPIO handling, battery monitoring |
| **7** | Add SD image package + installer + checks |
| **8** | Test on real hardware |

Kernel alternatives:
- **megi's kernel** (<https://github.com/megi/linux>) — Community fork with
  active PinePhone Pro support, updated regularly. Used by Manjaro ARM and
  Arch Linux ARM for PPP.
- **mobile-nixos kernel** (v6.4.7) — Old but known-working. DT patches are
  the most valuable part.
- **rockchip flake kernel** — If it already includes the PPP DT, no custom
  kernel needed at all.
