#!/usr/bin/env bash
set -euo pipefail
git config --global safe.directory /workspace 2>/dev/null
if [ -f secrets.nix ]; then
  git add -f secrets.nix
fi
if [ $# -eq 0 ]; then set -- .#image-gnome; fi
nix build "$@"
rc=$?
git reset -- secrets.nix 2>/dev/null || true
exit $rc
