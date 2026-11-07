#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-desktop}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$REPO_DIR"

if [[ ! -f "hosts/${HOST}/disko.nix" || ! -f "hosts/${HOST}/configuration.nix" ]]; then
  echo "Error: Unknown or incomplete host configuration: ${HOST}" >&2
  echo "Available host directories:" >&2
  find hosts -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' 2>/dev/null || true
  exit 1
fi

if [[ ! -f flake.nix ]]; then
  echo "Error: flake.nix not found in ${REPO_DIR}" >&2
  exit 1
fi

echo "WARNING: This will erase and repartition the disk configured for '${HOST}'."
read -r -p "Type 'install ${HOST}' to continue: " CONFIRM
if [[ "$CONFIRM" != "install ${HOST}" ]]; then
  echo "Installation cancelled."
  exit 1
fi

echo "==> Partitioning and mounting disk for ${HOST}..."
nix --extra-experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --flake ".#${HOST}"

echo "==> Installing NixOS for ${HOST}..."
nixos-install --flake ".#${HOST}"

echo "==> Installation complete for ${HOST}. You can now reboot."
