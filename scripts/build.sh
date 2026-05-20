#!/usr/bin/env bash
set -euo pipefail

# The Docker container runs as a different user than the host,
# so git sees the workspace directory as owned by "unknown".
git config --global safe.directory /workspace 2>/dev/null

# settings.nix is gitignored but needed at eval time.
# Temporarily stage it so nix can read it, then unstage.
if [ -f settings.nix ]; then
  git add -f settings.nix
fi

# Default to building the GNOME image for PineBookPro.
if [ $# -eq 0 ]; then set -- .#image-gnome; fi

nix build "$@"
rc=$?

git reset -- settings.nix 2>/dev/null || true
exit $rc
