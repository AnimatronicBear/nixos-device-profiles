#!/usr/bin/env bash
set -euo pipefail
git config --global safe.directory /workspace 2>/dev/null
if [ -f secrets.nix ]; then
  git add -f secrets.nix
fi
nix flake check "$@"
rc=$?
git reset -- secrets.nix 2>/dev/null || true
exit $rc
