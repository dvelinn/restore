#!/usr/bin/env bash
set -euo pipefail

# --- SETTINGS ---
REPO_SSH="git@github.com:dvelinn/nixos.git"   # NixOS private repo
CLONE_DIR="$HOME/.voidgazer"           # where to clone it
# ---------------

echo "[1/3] GitHub device login (approve on phone)…"
# If already logged in, this is a no-op.
nix run nixpkgs#gh -- auth status >/dev/null 2>&1 || \
nix run nixpkgs#gh -- auth login --hostname github.com --git-protocol ssh --web

echo "[2/3] Clone private repo via SSH…"
# (Using ephemeral git; avoids needing git preinstalled.)
if [ -d "$CLONE_DIR/.git" ]; then
  nix run nixpkgs#git -- -C "$CLONE_DIR" fetch --all --prune
  nix run nixpkgs#git -- -C "$CLONE_DIR" checkout main
  nix run nixpkgs#git -- -C "$CLONE_DIR" pull --ff-only
else
  nix run nixpkgs#git -- clone "$REPO_SSH" "$CLONE_DIR"
fi

echo "[3/3] Done. Using installer within cloned repo to build system."
exec "$CLONE_DIR/scripts/nix_install.sh"
