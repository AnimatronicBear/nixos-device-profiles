# Profiles

Named NixOS modules that group packages, services, and configuration for
specific use-cases. Profiles are composable — stack multiple profiles on
one build.

## Structure

Each profile lives in its own subdirectory:

```
profiles/
  base/
    default.nix              tracked — profile config
    secrets.nix              gitignored — real secrets
    secrets.nix.example      tracked — template
  development/
    default.nix
    secrets.nix
    secrets.nix.example
  minimal/
    default.nix
    secrets.nix
    secrets.nix.example
```

## Usage

Pass profile module paths to the builder in `flake.nix`:

```nix
PineBookPro-dev = myLib.rockchipOsConfigAarch64 "x86_64-linux"
  ./hosts/nixos/PineBookPro ./hosts/common/optional/gnome.nix
  [ ./profiles/base/default.nix ./profiles/development/default.nix ] null;
```

### Secrets

Each profile can have an optional `secrets.nix` companion (gitignored).
Secrets are auto-loaded by the builder from the same directory as each
profile's `default.nix` and merged into a `secrets` specialArg available
to all modules:

```nix
# profiles/development/secrets.nix
{ githubToken = "ghp_..."; npmToken = "npm_..."; }
```

Profiles access them gracefully:

```nix
# profiles/development/default.nix
{ pkgs, lib, secrets, ... }: {
  environment.variables.API_TOKEN =
    lib.mkIf (secrets ? apiToken) secrets.apiToken;
}
```

## Included profiles

| Profile | Contents |
|---------|----------|
| `base` | curl, wget, htop, git, tmux, vim |
| `development` | gcc, clang, llvm, gdb, cmake, python3, nodejs, rust, cargo, postgresql (imports base) |
| `minimal` | curl, git |
