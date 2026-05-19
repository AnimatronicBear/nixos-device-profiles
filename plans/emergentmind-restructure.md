# Plan: Restructure to EmergentMind/nix-config-starter layout

Reference: https://github.com/EmergentMind/nix-config-starter

## Motivation

The current repo is flat — all `.nix` files at root, device configs in a small `devices/` dir, and all logic
(checks, packages, installer) inlined in `flake.nix`. EmergentMind's layout separates concerns into
well-named top-level directories, making it easier to add hosts, users, and modules without
bloating `flake.nix`.

## Target directory tree

```
flake.nix              — thin: delegates to lib/, hosts/, modules/, checks.nix
flake.lock
checks.nix             — eval-only option assertions (extracted from flake.nix)
shell.nix              — dev shell with nixfmt, just, etc.
.envrc                 — direnv allow
justfile               — rebuild, check, update commands
compose.yaml           — keep as-is (docker CI)
secrets.nix            — keep at root or move to hosts/common/secrets/
secrets.nix.example

hosts/
  common/
    core/
      default.nix      — shared NixOS baseline (was config.nix: stateVersion, users,
                         SSH, pipewire, networkmanager, kernel params, zram, docker, etc.)
    optional/
      gnome.nix        — was gnome.nix
      plasma.nix       — was plasma.nix
      phosh.nix        — was phosh.nix
    secrets/
      default.nix      — secrets file (gitignored)
      default.nix.example
  nixos/
    PineBookPro/
      default.nix      — was devices/pinebook-pro.nix (hostName, uBoot, kernel, firmware)
      hardware.nix     — extracted hardware-specifics
    PineTab2/
      default.nix      — was devices/pinetab2.nix (hostName, uBoot, kernel, firmware, IIO, landscape)
      hardware.nix

home/
  <username>/
    common/
      core/
        default.nix    — was home.nix (home-manager: git, vscodium, firefox, packages)
    PineBookPro.nix    — per-host home overrides (if needed)
    PineTab2.nix

lib/
  default.nix          — osConfig / installerConfig helpers (extracted from flake.nix)

modules/
  nixos/
    default.nix        — custom NixOS option declarations (e.g. desktop variant selector)

overlays/
  default.nix          — package overlays (kernel versions, firmware)

pkgs/                  — custom packages (if any)

scripts/
  rebuild.sh           — nixos-rebuild wrapper
  helpers.sh           — shared shell functions

tests/                 — bats-based option tests (migrate from inline flake checks)

plans/                 — keep existing plans

docs/                  — optional: moved from plans/ or new docs
assets/wallpapers/     — optional: branding
```

## Migration steps

### Step 1 — Create directory skeleton

```bash
mkdir -p hosts/common/core hosts/common/optional hosts/common/secrets
mkdir -p hosts/nixos/PineBookPro hosts/nixos/PineTab2
mkdir -p home/bear/common/core
mkdir -p lib modules/nixos overlays scripts tests
```

### Step 2 — Move/copy files

| Current path | New path | Notes |
|---|---|---|
| `config.nix` | `hosts/common/core/default.nix` | Remove `secrets.nix` import — use `specialArgs` instead; strip `home-manager` block (goes in host config) |
| `gnome.nix` | `hosts/common/optional/gnome.nix` | No content change |
| `plasma.nix` | `hosts/common/optional/plasma.nix` | No content change |
| `phosh.nix` | `hosts/common/optional/phosh.nix` | Change `import ./secrets.nix` to use `specialArgs` |
| `home.nix` | `home/bear/common/core/default.nix` | No content change |
| `devices/pinebook-pro.nix` | `hosts/nixos/PineBookPro/default.nix` | No content change |
| `devices/pinetab2.nix` | `hosts/nixos/PineTab2/default.nix` | Remove `import ../secrets.nix` — use `specialArgs` |
| `secrets.nix` | `hosts/common/secrets/default.nix` | Gitignore this path |
| `secrets.nix.example` | `hosts/common/secrets/default.nix.example` | Tracked in git |

### Step 3 — Rewrite `lib/default.nix`

Extract the `osConfig` and `installerConfig` functions from current `flake.nix`:

```nix
# lib/default.nix
{ nixpkgs, rockchip, home-manager }:
{
  mkOsConfig = buildPlatform: hostModule: variantModule:
    nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit rockchip buildPlatform; };
      modules = [
        { nixpkgs.hostPlatform = "aarch64-linux"; }
        { nixpkgs.buildPlatform = buildPlatform; }
        rockchip.nixosModules.sdImageRockchip
        rockchip.nixosModules.noZFS
        home-manager.nixosModules.home-manager
        ./hosts/common/core
        hostModule
        variantModule
      ];
    };

  mkInstallerConfig = buildPlatform: hostModule:
    ... same but uses sdImageRockchipInstaller ...;
}
```

### Step 4 — Rewrite `flake.nix` (thin)

```nix
{
  inputs = { /* same as now */ };
  outputs = { self, nixpkgs, rockchip, utils, home-manager, ... }:
  let
    lib = import ./lib {
      inherit nixpkgs rockchip home-manager;
    };
  in {
    nixConfig = { /* same as now */ };

    nixosConfigurations = {
      PineBookPro       = lib.mkOsConfig "x86_64-linux" ./hosts/nixos/PineBookPro       ./hosts/common/optional/gnome;
      PineBookPro-plasma= lib.mkOsConfig "x86_64-linux" ./hosts/nixos/PineBookPro       ./hosts/common/optional/plasma;
      PineBookPro-phosh = lib.mkOsConfig "x86_64-linux" ./hosts/nixos/PineBookPro       ./hosts/common/optional/phosh;
      PineTab2          = lib.mkOsConfig "x86_64-linux" ./hosts/nixos/PineTab2          ./hosts/common/optional/gnome;
      PineTab2-plasma   = lib.mkOsConfig "x86_64-linux" ./hosts/nixos/PineTab2          ./hosts/common/optional/plasma;
      PineTab2-phosh    = lib.mkOsConfig "x86_64-linux" ./hosts/nixos/PineTab2          ./hosts/common/optional/phosh;
    };
  } // utils.lib.eachDefaultSystem (system: {
    packages = import ./pkgs { inherit lib system; };
    formatter = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    checks = import ./checks.nix { inherit lib system; };
  });
}
```

### Step 5 — Create `checks.nix`

Move the `mkCheck`, `assertEq`, etc. functions out of `flake.nix` into their own file.
Same assertion logic, just extracted.

### Step 6 — Create dev workflow files

**`shell.nix`**: dev shell with `nixfmt-tree`, `just`, `nix-output-monitor`, etc.

**`.envrc`**: `use flake` — enables direnv auto-load.

**`justfile`**: aliases for rebuild, check, build-image, update:

```just
rebuild host="PineBookPro":
    nixos-rebuild --flake .#$host switch --target-host $host ...

check:
    nix flake check

build-gnome:
    nix build .#image-gnome

...
```

### Step 7 — Move overlays

If any package version overrides exist, move to `overlays/default.nix`.
The rockchip kernel/firmware packages come via `specialArgs` and don't need overlays.

### Step 8 — Update compose.yaml paths

`compose.yaml` command paths (`nix build .#image-gnome`, `nix flake check`)
should still work since the flake outputs haven't changed names.

### Step 9 — Remove old files

```bash
git rm config.nix gnome.nix plasma.nix phosh.nix home.nix
git rm devices/pinebook-pro.nix devices/pinetab2.nix
rmdir devices/  # if empty
```

## Design decisions to make before implementing

1. **sops-nix vs plain secrets**: Starter uses sops-nix with a separate `nix-secrets` repo
   (gitignored sibling directory). Current pinetab2-nixos uses `secrets.nix` (gitignored).
   Keeping plain `secrets.nix` (moved to `hosts/common/secrets/`) is simpler and avoids
   the sops learning curve. Decision: **keep plain secrets.nix** unless you want sops.

2. **Per-user home-manager split**: Starter has `home/<user>/hostname1.nix` for per-host
   home overrides. Currently home config is identical across devices. If you want per-device
   home settings later, the structure supports it.

3. **Desktop variant selection**: Current approach (pass variant as a module arg) is clean.
   Could also define a `desktop` option in `modules/nixos/` and select the right module
   automatically from the host config. Decision: **keep current approach** for minimal diff.

4. **Live builder vs manual `nix build`**: Starter's `justfile` has `rebuild`, `check`,
   `update` targets. The current `docker compose run build` CI approach stays in
   `compose.yaml`.

5. **`settings.nix` from `plans/settings-split.md`**: That earlier plan suggested splitting
   `username` and `extraPackages` out of `secrets.nix` into a tracked `settings.nix`.
   This can be folded into the restructure: create `hosts/common/settings/default.nix`
   as a tracked file with non-secret user preferences.

## Estimated effort

| Step | Files touched | Risk |
|------|--------------|------|
| 1-2 (mkdir + mv) | 0 (just moves) | None |
| 3 (lib/default.nix) | 1 new | Low — mechanical extraction |
| 4 (flake.nix rewrite) | 1 changed | Medium — path changes, testing needed |
| 5 (checks.nix) | 1 new | Low — mechanical extraction |
| 6 (shell.nix, .envrc, justfile) | 3 new | None |
| 7 (overlays) | 1 new | None |
| 8 (compose.yaml) | 0 | None |
| 9 (cleanup) | ~7 deleted | Low — git tracks history |

Total: ~6 new files, 1 changed file, ~7 deleted files.
