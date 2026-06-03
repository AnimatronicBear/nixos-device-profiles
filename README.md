# nixos-device-profiles

**⚠ WIP — NOT FUNCTIONAL. Do not use for production or anything security-sensitive.**

Multi-device NixOS flake — cross-compiled from x86_64 → aarch64-linux.
Currently supports **PineBookPro** (RK3399), **PineTab2** (RK3566),
**generic aarch64** SBCs, and **x86_64 PC** installer ISOs (native build).

Forked from [raboof/pinetab2-nixos](https://codeberg.org/raboof/pinetab2-nixos)
(PineTab2-only).

Mirrored on [Codeberg](https://codeberg.org/AnimatronicBear/nixos-device-profiles)
and [GitHub](https://github.com/AnimatronicBear/nixos-device-profiles).

**⚠ LLM Assisted / Generated Experimental Work**
Post-fork changes (settings split, device modules, overlays,
CI structure) are **largely LLM-generated and have not been thoroughly reviewed by a
human.** The flake may eval but images may fail to build or boot, and
configuration may be insecure. Use at your own risk.

## Supported configurations

| Device | Desktop | nixosConfiguration | Package (image) |
|--------|---------|-------------------|-----------------|
| PineBookPro | GNOME | `.#nixosConfigurations.pinebookpro-gnome` | `.#image-pinebookpro-gnome` |
| PineBookPro | Plasma 6 | `.#pinebookpro-plasma` | `.#image-pinebookpro-plasma` |
| PineBookPro | Phosh | `.#pinebookpro-phosh` | `.#image-pinebookpro-phosh` |
| PineBookPro | GNOME + dev profile | `.#pinebookpro-dev` | `.#image-pinebookpro-dev` |
| PineBookPro | Installer | `.#pinebookpro-installer` | `.#image-pinebookpro-installer` |
| PineTab2 | GNOME | `.#pinetab2-gnome` | `.#image-pinetab2-gnome` |
| PineTab2 | Plasma 6 | `.#pinetab2-plasma` | `.#image-pinetab2-plasma` |
| PineTab2 | Phosh | `.#pinetab2-phosh` | `.#image-pinetab2-phosh` |
| PineTab2 | Installer | `.#pinetab2-installer` | `.#image-pinetab2-installer` |
| Generic aarch64 | GNOME | `.#generic-aarch64-gnome` | `.#image-generic-aarch64-gnome` |
| Generic aarch64 | Installer | `.#generic-aarch64-installer` | `.#image-generic-aarch64-installer` |
| Generic aarch64 | GNOME + botany-bay | `.#cc-generic-aarch64-botany-bay` | `.#image-cc-generic-aarch64-botany-bay` |
| Aarch64LUKS | GNOME + botany-bay | `.#aarch64-luks-botany-bay` | — (system only) |
| x86_64 PC | Installer (console) | — | `.#image-x86pc` |
| x86_64 PC | Installer (GNOME) | — | `.#image-x86pc-gnome` |
| x86_64 PC | Installer (Plasma) | — | `.#image-x86pc-plasma` |

## Device docs

Device-specific build, flash, u-boot, and remote update instructions:

| Device | Doc |
|--------|-----|
| PineBookPro (RK3399) | [docs/pinebookpro.md](docs/pinebookpro.md) |
| PineTab2 (RK3566) | [docs/pinetab2.md](docs/pinetab2.md) |
| Generic aarch64 SBC | [docs/generic-aarch64.md](docs/generic-aarch64.md) |
| x86_64 PC installer | [docs/x86pc.md](docs/x86pc.md) |

## Before building

### 1. `settings.nix` (gitignored)

Copy `settings.nix.example` to `settings.nix` and edit — set your `username`,
`initialPassword`, `authorizedKey`, `ssid`, `psk`, git config, and
package preferences.

## Variants (build targets)

Build targets are defined in `variants/*.nix`. Each file describes a
composition of host device module + desktop environment + profiles +
platform + build type. `lib/fromVariant.nix` auto-discovers these files
and generates `nixosConfigurations`, `packages` (images, installers,
ISOs, u-boot), and `checks` — no `flake.nix` changes needed.

```nix
# variants/pinebookpro-plasma.nix
{
  variant = "pinebookpro-plasma";
  host = "PineBookPro";
  desktop = "plasma";                         # optional/plasma.nix
  buildType = "image";                        # image|installer|iso|uboot|none
  platform = "rockchip";
  cross = true;
  checkProfiles = [ "plasma" ];               # assertion checks to run
}
```

Adding a new target: copy an existing variant, adjust fields, and it
appears in all flake outputs automatically.

## Building an image

The [Quick reference](#quick-reference) table below lists every buildable
output. Builds run inside a Docker container (no host nix-daemon required):

```shell
docker compose run build                      # default: pinebookpro-gnome
docker compose run build .#image-pinebookpro-plasma
docker compose run build .#image-pinetab2-gnome
docker compose run build .#image-generic-aarch64-gnome
docker compose run build .#image-x86pc
```

Flash the result:

```shell
# SD card images (aarch64 ARM targets)
dd if=result/sd-image/* of=/dev/sdX bs=4M

# ISO images (x86_64 PC targets)
dd if=result/iso-image/*.iso of=/dev/sdX bs=4M status=progress
```

## Updating a running system

```shell
docker compose run deploy <config> user@host
docker compose run deploy <config> user@host --ask-sudo-password
```

Replace `<config>` with the configuration name (e.g. `pinebookpro-gnome`,
`pinetab2-gnome`, `generic-aarch64-gnome`, `pinebookpro-plasma`).

The `deploy` service mounts your SSH keys and `known_hosts` from
`~/.ssh/`, stages `settings.nix`, and runs `nixos-rebuild --target-host
--use-remote-sudo` inside a container.

## Key packages

| Package | Where | Notes |
|---------|-------|-------|
| `git`, `htop` | System (`settings.nix`) | `extraSystemPackages` |
| `docker` | System (`hosts/common/core/default.nix`) | User in `docker` group |
| `librewolf`, `ungoogled-chromium`, `vscodium` | User (`settings.nix`) | `extraUserPackages` |

System packages and user packages are configured in `settings.nix` (see
`settings.nix.example`). User dotfiles (git config, VSCodium extensions,
browser settings) are managed by
[home-manager](https://github.com/nix-community/home-manager) in
`home/_username_/common/core/default.nix`.

### Per-node secrets

`settings.nix` supports a `Common` + `nodes` structure for per-device secrets:

```nix
{
  Common = { username = "bear"; stateVersion = "25.11"; };
  nodes = {
    PineBookPro = { hostName = "rotarran"; authorizedKey = "ssh-ed25519 ..."; };
    PineTab2    = { hostName = "tabby";    authorizedKey = "ssh-ed25519 ..."; };
  };
}
```

When `configName` is passed to the builder (e.g. `"PineBookPro"`), the
corresponding node overrides are merged over `Common`. If no `nodes` attr
exists, `settings.nix` works as a flat attrset (backward compatible).

## Profiles

Composable NixOS modules in `profiles/<name>/default.nix` that bundle packages
and config for specific use-cases. Stack multiple profiles on one build
(via the variant's `profiles` list).

| Profile | Contents |
|---------|----------|
| `profiles/base` | curl, wget, htop, git, tmux, vim |
| `profiles/development` | gcc, clang, llvm, cmake, python3, nodejs, rust, postgresql |
| `profiles/minimal` | curl, git |
| `profiles/botany-bay` | Aarch64LUKS-specific: iwd, immich, trogdord, radarr, prowlarr, syncthing |

### Profile secrets

Each profile can have an optional `secrets.nix` companion (gitignored):

```nix
# profiles/development/secrets.nix
{ githubToken = "ghp_..."; npmToken = "npm_..."; }
```

Template files (`secrets.nix.example`) are tracked in git alongside each
profile — copy to `secrets.nix` and fill in real values.

The builder auto-loads and merges all profile `secrets.nix` files, then
passes the result as a `secrets` specialArg to all NixOS and home-manager
modules. Profile modules access secrets gracefully:

```nix
{ pkgs, lib, secrets, ... }: {
  environment.variables.API_TOKEN =
    lib.mkIf (secrets ? apiToken) secrets.apiToken;
}
```

## Binary cache

The flake uses `nabam-nixos-rockchip.cachix.org` for pre-built kernels,
u-boot, and firmware (configured at both the flake and NixOS system level).

## Security

**CVE-2026-31431 (Copy Fail)** is mitigated by blacklisting `algif_aead`
in `hosts/common/core/default.nix`. The nixpkgs stable input is updated to a kernel containing
the upstream fix (available for PineBookPro; PineTab2 uses a custom DanctNIX
kernel that relies on the blacklist workaround).

## Docker compose

Run nix build and checks inside a container without a host nix-daemon:

```shell
docker compose run check
docker compose run build              # builds .#image-pinebookpro-gnome (default)
docker compose run build .#image-pinebookpro-plasma
docker compose run build .#image-pinetab2-gnome
docker compose run build .#image-generic-aarch64-gnome
docker compose run build .#image-x86pc
docker compose run build .#image-x86pc-gnome
docker compose run dev                # interactive shell
docker compose run fmt
docker compose run deploy pinebookpro-gnome user@host  # remote deploy
```

A named Docker volume (`nix-store`) is used for `/nix`, preserving the
container's built-in nix binary while caching store paths across runs
(needs root Docker).

Image version and nix config are set in `.env` (copy `.env.example` to `.env`).

## Checks

```shell
nix flake check                    # eval-only, no kernel compilation
docker compose run check

# Individual checks:
nix build .#checks.x86_64-linux.pinebookpro-gnome
docker compose run build .#checks.x86_64-linux.pinebookpro-gnome
nix build .#checks.x86_64-linux.pinetab2-plasma
docker compose run build .#checks.x86_64-linux.pinetab2-plasma
nix build .#checks.x86_64-linux.generic-aarch64-gnome
docker compose run build .#checks.x86_64-linux.generic-aarch64-gnome
nix build .#checks.x86_64-linux.x86pc
docker compose run build .#checks.x86_64-linux.x86pc
nix build .#checks.x86_64-linux.x86pc-gnome
docker compose run build .#checks.x86_64-linux.x86pc-gnome
nix build .#checks.x86_64-linux.x86pc-plasma
docker compose run build .#checks.x86_64-linux.x86pc-plasma
```

## Code formatting

```shell
nix fmt                 # uses nixfmt-tree
docker compose run fmt
```

## Quick reference

| Action | nix command | Docker compose |
|--------|-------------|----------------|
| Build image (PineBookPro GNOME) | `nix build` | `docker compose run build` |
| Build image (PineBookPro dev profile) | `nix build .#image-pinebookpro-dev` | `docker compose run build .#image-pinebookpro-dev` |
| Build image (PineTab2 GNOME) | `nix build .#image-pinetab2-gnome` | `docker compose run build .#image-pinetab2-gnome` |
| Build image (generic aarch64 GNOME) | `nix build .#image-generic-aarch64-gnome` | `docker compose run build .#image-generic-aarch64-gnome` |
| Build installer (PineBookPro) | `nix build .#image-pinebookpro-installer` | `docker compose run build .#image-pinebookpro-installer` |
| Build installer (PineTab2) | `nix build .#image-pinetab2-installer` | `docker compose run build .#image-pinetab2-installer` |
| Build installer (generic aarch64) | `nix build .#image-generic-aarch64-installer` | `docker compose run build .#image-generic-aarch64-installer` |
| Build x86_64 ISO (console) | `nix build .#image-x86pc` | `docker compose run build .#image-x86pc` |
| Build x86_64 ISO (GNOME) | `nix build .#image-x86pc-gnome` | `docker compose run build .#image-x86pc-gnome` |
| Build x86_64 ISO (Plasma) | `nix build .#image-x86pc-plasma` | `docker compose run build .#image-x86pc-plasma` |
| Build u-boot (PineBookPro) | `nix build .#uboot` | `docker compose run build .#uboot` |
| Build u-boot (PineTab2) | `nix build .#uboot-pinetab2` | `docker compose run build .#uboot-pinetab2` |
| Run all checks | `nix flake check` | `docker compose run check` |
| Format Nix files | `nix fmt` | `docker compose run fmt` |
| Interactive shell | — | `docker compose run dev` |
| Remote deploy | `nixos-rebuild --target-host user@host --use-remote-sudo --ask-sudo-password` | `docker compose run deploy <cfg> user@host` |
