# Plan: Qubes OS template qube image output

## What a Qubes template is

In Qubes OS, every app qube is based on a **template** — a root filesystem image
that app qubes inherit read-only. Templates are distributed as **RPM packages**
that dom0 installs via `qvm-template install`. The RPM contains:

```
qubeized_images/<name>/root.img   — ext4 filesystem image (~10 GB)
appmenus/                          — .desktop entries for the template's apps
template.conf                      — template metadata (vm settings, etc.)
version                            — version string
build_timestamp                    — build timestamp for update checks
```

**This is an x86_64 artifact only** — Qubes OS runs on x86_64 hardware.
ARM devices (PineBookPro, PineTab2) cannot run Qubes.

## Existing reference: evq/qubes-nixos-template

The primary existing work lives at https://github.com/evq/qubes-nixos-template.
It provides:

| Component | What it does |
|-----------|-------------|
| `pkgs/qubes-core-*/` | Nix package derivations for Qubes services (qrexec, qubesdb, vchan-xen, gui-agent, usb-proxy, gpg-split, linux-utils, sshd) |
| `pkgs/qubes-core-agent-linux/` | The main Qubes guest agent (udev rules, systemd services, qrexec services) |
| `pkgs/qubes-gui-agent-linux/` | GUI agent (X11/VNC-based display for app qubes) |
| `modules/qubes/*.nix` | NixOS modules that wire up the above packages (core, db, gui, networking, qrexec, sshd, updates, usb) |
| `profiles/qubes.nix` | Profile that bundles all Qubes modules into a ready-to-use config |
| `tools/rpm.nix` | Derivation that builds the `qubeized_images/root.img` using `make-disk-image.nix`, then wraps it in an RPM |
| `tools/iso.nix` | An unattended installer ISO for manual HVM installation |

The RPM is built via `nix build .#rpm` which:
1. Builds a NixOS system closure with the Qubes profile
2. Runs `make-disk-image.nix` to produce `root.img` (ext4, 10 GB sparse)
3. Fetches `QubesOS/qubes-linux-template-builder` RPM spec
4. Runs `build_template_rpm` to produce `qubes-template-nixos-<version>.noarch.rpm`

## How this integrates with the current flake

The current flake targets **aarch64-linux** ARM devices exclusively. A Qubes
template targets **x86_64-linux**. These are completely separate build targets
that can coexist in the same flake.

### New structure under the emergentmind layout

```
qubes/
  pkgs/                    — Qubes package derivations (upstream from evq)
    qubes-core-qubesdb/
    qubes-core-vchan-xen/
    qubes-core-qrexec/
    qubes-core-agent-linux/
    qubes-linux-utils/
    qubes-gui-common/
    qubes-gui-agent-linux/
    qubes-sshd/
    qubes-usb-proxy/
    qubes-gpg-split/
  modules/
    qubes/                 — NixOS modules for Qubes integration (upstream from evq)
      core.nix
      db.nix
      gui.nix
      networking.nix
      qrexec.nix
      sshd.nix
      updates.nix
      usb.nix
  profiles/
    qubes.nix              — profile bundling all Qubes modules
    minimal.nix            — minimal template (no GUI)
    gnome.nix              — GNOME desktop template
    plasma.nix             — Plasma desktop template
  configs/
    configuration.nix      — template's NixOS config
    flake.nix              — flake copied into template for local rebuilds
  tools/
    rpm.nix                — RPM builder (adapted from evq)
    iso.nix                — unattended installer ISO builder (adapted from evq)
  outputs/
    rpm                    — built RPM (nix build .#qubes.rpm.gnome)
    iso                    — installer ISO (nix build .#qubes.iso.gnome)
```

### Flake additions

```nix
let
  qubesSystem = system: configModule:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        qubesModules
        qubesProfile
        configModule
      ];
    };
in {
  # Qubes template variants (x86_64-linux only)
  packages.x86_64-linux = {
    qubes-rpm-minimal = callPackage ./qubes/tools/rpm.nix {
      nixosConfig = qubesSystem "x86_64-linux" ./qubes/configs/minimal.nix;
      variant = "minimal";
    };
    qubes-rpm-gnome = callPackage ./qubes/tools/rpm.nix {
      nixosConfig = qubesSystem "x86_64-linux" ./qubes/configs/gnome.nix;
      variant = "gnome";
    };
    qubes-iso-minimal = (qubesSystem "x86_64-linux" ./qubes/tools/iso.nix).config.system.build.isoImage;
  };
}
```

### Template configuration (`qubes/configs/gnome.nix`)

```nix
{ pkgs, lib, ... }: {
  imports = [
    ../modules/qubes
    ../profiles/qubes.nix
  ];
  networking.hostName = "nixos";

  # Qubes template needs Xen kernel, not the default
  boot.kernelPackages = pkgs.linuxPackages_xen;

  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Qubes-specific kernel modules
  boot.initrd.kernelModules = [ "xen-blkback" "xen-netback" "xen-kbdfront" "xen-fbfront" ];
  boot.kernelModules = [ "xen-evtchn" "xen-privcmd" ];

  # Qubes-specific services
  services.qubes.core.enable = true;
  services.qubes.gui.enable = true;
  services.qubes.qrexec.enable = true;
  services.qubes.networking.enable = true;

  system.stateVersion = "25.11";
}
```

## Approach: fork evq's work vs. incorporate upstream

| Approach | Pros | Cons |
|----------|------|------|
| **Copy evq's packages/modules** into `qubes/` dir | Full control; no external dependency | Duplication; need to track upstream updates |
| **Add evq as a flake input** | Minimal code in this repo; upstream handles updates | Depends on evq maintaining compatibility; may not match needs |
| **Contribute upstream to evq** | Best for community; share maintenance | Requires coordination; slower |

**Recommended**: Copy evq's work into `qubes/` as the starting point, with clear
attribution. The Qubes packages are stable (the protocol between Qubes dom0 and
template VMs doesn't change often). Adding evq as a flake input would also work
if his module interface is clean enough.

## Qubes template update proxy (networking)

This is the trickiest part. Qubes templates normally use `qubes-update-proxy`
via qrexec for network access — the template VM has no direct network. Nix
downloads don't go through a global proxy by default.

evq's solution: set `all_proxy` in the nix-daemon environment and provide
shell aliases for interactive nix commands. This works but has edge cases
(`sudo nix` doesn't inherit the proxy, remote flake inputs over SSH need
workarounds).

For the template to be useful for `nixos-rebuild` inside the template:
- `nix-daemon` must have `all_proxy` pointing at the qubes update proxy
- `sudo` must preserve the proxy environment
- `~/.ssh/config` needs the GitHub SSH workaround for the qubes proxy

## Building the RPM

The RPM builder (`qubes/tools/rpm.nix`):

```
nix build .#qubes-rpm-gnome
  ↓
make-disk-image.nix  ─→  root.img (ext4, 10 GB, sparse)
  ↓
qubes-linux-template-builder  ─→  qubes-template-nixos-4.2.0.noarch.rpm
  ↓
result/qubes-template-nixos-4.2.0.noarch.rpm
```

The resulting RPM is copied to dom0 and installed:
```bash
qvm-run --pass-io <download-vm> 'cat qubes-template-nixos-*.noarch.rpm' \
  > qubes-template-nixos-4.2.0.noarch.rpm
qvm-template install qubes-template-nixos-4.2.0.noarch.rpm --nogpgcheck
```

## Distribution via RPM repository

For production use, templates are served from an RPM repository so dom0 can
use `qvm-template install qubes-template-nixos` directly. This requires:

1. Sign the RPM with a GPG key
2. Serve it via HTTP (e.g. GitHub Releases, Codeberg Pages, or a static server)
3. Add a repo definition in dom0 at `/etc/qubes/repo-templates/nixos.conf`

A Woodpecker CI pipeline (see `plans/codeberg-ci.md`) could automate this:
- On tag push: build RPM, sign it, upload to release assets
- The repo metadata (`repodata/repomd.xml`) can be generated with `createrepo`

## Desktop variants

| Variant | Purpose | Size |
|---------|---------|------|
| **Minimal** | CLI-only template, no X11 | ~2 GB root.img |
| **GNOME** | Full GNOME desktop template | ~4 GB root.img |
| **Plasma** | Plasma 6 desktop template | ~4 GB root.img |
| **Xfce** | Lightweight desktop template | ~3 GB root.img |

## Implementation phases

| Phase | What | Files |
|-------|------|-------|
| **1** | Copy Qubes package derivations from evq (with attribution) | `qubes/pkgs/*/` |
| **2** | Copy Qubes NixOS modules from evq | `qubes/modules/qubes/*.nix` |
| **3** | Create Qubes profile that bundles all modules | `qubes/profiles/qubes.nix` |
| **4** | Create RPM builder derivation | `qubes/tools/rpm.nix` |
| **5** | Create template config (minimal + GNOME variants) | `qubes/configs/{minimal,gnome}.nix` |
| **6** | Wire up flake outputs (x86_64-linux packages) | `flake.nix` |
| **7** | Build & test RPM in a local Qubes installation | shell |
| **8** | (Optional) Create unattended installer ISO | `qubes/tools/iso.nix` |
| **9** | Add Woodpecker CI job to build RPM on tag | `.woodpecker/build-qubes-template.yml` |
| **10** | Wire up RPM repo signing + release upload | `.woodpecker/release.yml` |

## Open questions

| Question | Options |
|----------|---------|
| **How to handle the qubes-update-proxy for nix?** | evq's approach (all_proxy in nix-daemon) works but has edge cases. Could also give the template direct network access in a firewall VM. |
| **Which Qubes version to target?** | Qubes 4.2 is stable; 4.3 is current. The protocol is largely the same. evq packages `qubesVersion = "4.2.0"`. |
| **Should the template support `nixos-rebuild` in-place?** | Yes — copy the flake + config into `/etc/nixos/` so users can customize and rebuild. This is what evq does with the `examples/` files. |
| **How large should root.img be?** | 10 GB is typical for Qubes templates. `make-disk-image.nix` with `diskSize = 10240` produces a sparse image. |
| **GPG signing key for RPM?** | Need a key for the repo. Could generate one in CI and store the private key as a CI secret. |
