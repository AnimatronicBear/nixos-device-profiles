# Plan: CI/CD for Codeberg (Woodpecker)

Codeberg's native CI is **Woodpecker** (a Drone fork). Pipelines are defined
as YAML in the repo root. Each step runs in a container — the same
`nixos/nix:2.34.7` image already used in `compose.yaml`.

## Woodpecker vs GitHub Actions

| Aspect | GitHub Actions | Woodpecker (Codeberg) |
|--------|---------------|----------------------|
| Config file | `.github/workflows/*.yml` | `.woodpecker/*.yml` |
| Container | `nixbuild/nix-quick-install-action` | `nixos/nix:2.34.7` (same as compose.yaml) |
| Cache | `actions/cache` | Woodpecker `volumes` + manual tar |
| Secrets | `${{ secrets.X }}` | `${{ secrets.X }}` (set in repo UI) |
| Matrix | `matrix:` strategy | `matrix:` with `include` |
| Artifacts | `actions/upload-artifact` | `file:` in `publish` step or CLI |
| Max runtime | 6 h (free) | 6 h (Codeberg) |
| Storage | ~10 GB workspace | ~10 GB, flushed if >20 GB |

## Pipeline design

```
Commits ──→ Checks (eval-only, fast)  ──→ Images (build, slow) ──→ Release
                 ~1 min                        ~2 h per image        (tagged)
```

### Pipeline: Checks (`nix flake check`)

Runs on every push and PR. Fast (no kernel compile). Catches eval errors.

```yaml
when:
  event: [push, pull_request]

steps:
  flake-check:
    image: nixos/nix:2.34.7
    environment:
      - NIX_CONFIG=experimental-features = nix-command flakes
    commands:
      - git config --global safe.directory /workspace
      - nix flake check
```

Equivalent to `docker compose run check`. ~1–2 min runtime.

### Pipeline: SD image builds (separate, triggered manually or on tag)

```yaml
when:
  event: tag
  tag: v*

matrix:
  include:
    - target: image-gnome
    - target: image-plasma
    - target: image-pinetab2-gnome
    - target: image-pinetab2-plasma

steps:
  build:
    image: nixos/nix:2.34.7
    environment:
      - NIX_CONFIG=experimental-features = nix-command flakes
    commands:
      - git config --global safe.directory /workspace
      - nix build .#${target}
  publish:
    commands: ...
```

~2 h per target, runs on tag push. Matrix builds run in parallel.

## Caching strategy

Nix builds are expensive. Without caching, each CI run starts from scratch.

### Option A: Nix binary cache (Cachix or self-hosted)

**Recommended.** Push built store paths to a binary cache on every image build.
Subsequent runs pull them instead of rebuilding.

```yaml
steps:
  build:
    image: nixos/nix:2.34.7
    secrets: [cachix_auth_token]
    commands:
      - nix build .#${target}
      - nix copy --to 's3://my-cache?scheme=https&endpoint=my-server' --all
```

For Codeberg specifically, **Cachix** is the easiest option (free for public repos):
1. Sign up at https://app.cachix.org
2. Create a cache (e.g. `nixos-device-profiles`)
3. Generate a write token
4. Add `CACHIX_AUTH_TOKEN` as a CI secret in the Codeberg repo

Alternatively, use Codeberg's own **Forgejo Packages** or a simple S3 bucket.

### Option B: Woodpecker volume cache

Cache `/nix` as a Woodpecker volume between runs. Works for small repos
but volumes are per-runner and can be evicted at any time.

```yaml
steps:
  restore-cache:
    image: nixos/nix:2.34.7
    commands:
      - tar -xzf /cache/nix-store.tar.gz -C / || true
  build:
    image: nixos/nix:2.34.7
    commands:
      - nix build .#${target}
  save-cache:
    image: nixos/nix:2.34.7
    commands:
      - tar -czf /cache/nix-store.tar.gz /nix
```

### Option C: Use the existing compose.yaml as-is

Woodpecker can call `docker compose` if the runner has Docker socket access.
This is fragile and not recommended for Codeberg shared runners.

## Secrets handling

Gitignored `secrets.nix` won't be available in CI. Strategy:

1. Set `secrets.nix`-equivalent values as Woodpecker CI secrets in the repo UI:
   - `INITIAL_PASSWORD`
   - `AUTHORIZED_KEY`
   - `SSID`
   - `PSK`

2. In CI, materialize `secrets.nix` from those secrets before building:

```yaml
steps:
  setup-secrets:
    image: nixos/nix:2.34.7
    secrets: [initial_password, authorized_key, ssid, psk]
    commands: |
      cat > secrets.nix << EOF
      {
        username = "ci";
        initialPassword = "$INITIAL_PASSWORD";
        authorizedKey = "$AUTHORIZED_KEY";
        ssid = "$SSID";
        psk = "$PSK";
      }
      EOF
```

Or, for image builds that don't need SSH/WiFi, simply skip secrets entirely
and set dummy values (WiFi profile and SSH key don't affect the system closure):

```yaml
steps:
  setup-secrets:
    image: alpine:3.21
    commands: |
      cat > /workspace/secrets.nix << 'EOF'
      {
        username = "ci";
        initialPassword = "changeme";
        authorizedKey = "";
        ssid = "";
        psk = "";
      }
      EOF
```

`authorizedKey = ""` → `services.openssh.enable = false` (via the
conditional in `config.nix`). The closure is identical to any real build.

## Recommended `.woodpecker/` file structure

```
.woodpecker/
  check.yml           — nix flake check (push + PR)
  build-image.yml     — nix build .#<target> (tag or manual)
  format.yml          — nixfmt-tree check
  nightly.yml         — full matrix build on schedule
```

For a single-file approach, `.woodpecker.yml` at root also works.

## Artifacts: SD images as release assets

On a tag push (`v0.1.0`), after building SD images:

```yaml
steps:
  upload:
    image: woodpeckerci/plugin-s3
    settings:
      source: result/sd-image/*.img.zst
      target: https://codeberg.org/api/packages/${CI_REPO}/generic/releases/${CI_TAG}/
```

Or use `curl` to attach to a Codeberg release:

```yaml
steps:
  release:
    image: alpine/curl:8.13
    secrets: [forgejo_token]
    commands: |
      for img in result/sd-image/*.img.zst; do
        curl -X POST \
          -H "Authorization: token $FORGEJO_TOKEN" \
          -H "Content-Type: application/octet-stream" \
          "https://codeberg.org/api/repos/${CI_REPO}/releases" \
          -F "attachment=@$img"
      done
```

## Disk space management

Nix builds consume significant disk space (`/nix/store` grows large).
Woodpecker flushes the workspace if it exceeds ~20 GB. Mitigations:

- Use `nix store optimise` after builds to deduplicate
- Set `nix.settings.auto-optimise-store = true` (already in `config.nix`)
- For image builds, only keep the final `result` symlink's closure:
  ```
  nix store gc --keep-outputs
  ```

## Implementation phases

| Phase | What | Files |
|-------|------|-------|
| **1** | Create `.woodpecker/check.yml` — eval-only check on push | `.woodpecker/check.yml` |
| **2** | Create `.woodpecker/format.yml` — nixfmt-tree linting | `.woodpecker/format.yml` |
| **3** | Add Cachix binary cache to `nix.settings` in `config.nix` | `config.nix` |
| **4** | Create `.woodpecker/build-image.yml` — matrix SD image build on tag | `.woodpecker/build-image.yml` |
| **5** | Add secrets materialization step | `.woodpecker/build-image.yml` |
| **6** | Wire up release artifact upload | `.woodpecker/release.yml` |
| **7** | Test with a dummy tag push | shell |

## Alternatives considered

| Alternative | Verdict | Reason |
|-------------|---------|--------|
| **Forgejo Actions** | Possible, but Woodpecker is Codeberg's first-party CI | Woodpecker has tighter Codeberg integration; Actions would need a separate runner |
| **SourceHut builds** | Not compatible | SourceHut has its own CI (`sr.ht`) with Alpine-based build VMs, no Docker |
| **GitLab CI** | Not on Codeberg | Different platform entirely |
| **Manual / local builds** | Falls back to existing `docker compose` workflow | No CI benefits |
