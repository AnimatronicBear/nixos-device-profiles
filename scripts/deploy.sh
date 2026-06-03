#!/usr/bin/env bash
set -euo pipefail

git config --global safe.directory /workspace 2>/dev/null

# settings.nix is gitignored but needed at eval time.
# Temporarily stage it so nix can read it, then unstage.
if [ -f settings.nix ]; then
  git add -f settings.nix
fi

if [ $# -lt 2 ]; then
  echo "Usage: $0 <flake-attr> <user@host> [--ask-sudo-password]"
  echo ""
  echo "Builds and deploys a NixOS configuration to a remote host."
  echo ""
  echo "Arguments:"
  echo "  <flake-attr>     NixOS configuration attribute (e.g. PineBookPro)"
  echo "  <user@host>      Target host for deployment (e.g. user@pinebookpro.local)"
  echo "  --ask-sudo-password  Prompt for sudo password on target (optional)"
  echo ""
  echo "Examples:"
  echo "  docker compose run deploy PineBookPro user@10.0.0.42"
  echo "  docker compose run deploy PineBookPro user@host --ask-sudo-password"
  exit 1
fi

FLAKE_ATTR="$1"
TARGET_HOST="$2"
shift 2

# Ensure SSH key permissions are correct inside the container.
# Mounted host keys may have restricted permissions that need adjusting
# when running as root.
chmod 600 /root/.ssh/id_ed25519 2>/dev/null || true

nix shell nixpkgs#nixos-rebuild -c nixos-rebuild \
  --flake "/workspace#$FLAKE_ATTR" \
  switch \
  --target-host "$TARGET_HOST" \
  --use-remote-sudo \
  "$@"
rc=$?

git reset -- settings.nix 2>/dev/null || true
exit $rc
