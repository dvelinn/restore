#!/usr/bin/env bash
set -euo pipefail

# --- SETTINGS ---
REPO_SSH="git@github.com:dvelinn/nixos.git"
CLONE_DIR="$HOME/.voidgazer"
# ---------------

echo "[1/3] GitHub device login (approve on phone)…"
gh auth login --hostname github.com --git-protocol ssh --web

echo "[2/3] Clone private repo via SSH…"
gh repo clone "$REPO_SSH"
mv nixos .voidgazer

echo "[3/3] Done. Using installer to build system."
exec "$CLONE_DIR/scripts/nix_install.sh"
