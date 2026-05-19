# Plan: split user-customizable options from secrets

## Motivation

`secrets.nix` currently contains `username`, which is not a secret value.
User-customizable non-secret settings (git name/email, extra packages, etc.)
are scattered between `config.nix` and `home.nix` with no single override point.

## New file: `settings.nix`

Tracked in git. Contains only non-secret user preferences.

```nix
{
  username = "bear";
  stateVersion = "25.11";
  gitUserName = "Your Name";
  gitUserEmail = "your@email.com";
  extraSystemPackages = [ "git" "htop" ];
  extraUserPackages = [ "librewolf" "ungoogled-chromium" "vscodium" ];
}
```

## Updated `secrets.nix`

Remains gitignored. `username` removed — the rest stays (initialPassword,
authorizedKey, ssid, psk).

## Changes by file

| File | Change |
|------|--------|
| **settings.nix** | **Create** |
| **secrets.nix** | Remove `username` |
| **secrets.nix.example** | Remove `username` |
| **config.nix** | Import `settings.nix`; use `username`, `stateVersion`, `extraSystemPackages` from it |
| **devices/pinetab2.nix** | `import ../secrets.nix` → `import ../settings.nix` for `username` |
| **home.nix** | Accept `gitUserName`, `gitUserEmail`, `extraUserPackages` as function args; use `extraUserPackages` instead of hardcoded list |
| **flake.nix** | Add `settings` to `specialArgs` so all modules can reference it without re-importing |
| **README.md** | Document `settings.nix` as the place for non-secret overrides |
| **CHANGELOG.md** | Entry for the restructure |
| **.gitignore** | No change — `settings.nix` is tracked |
