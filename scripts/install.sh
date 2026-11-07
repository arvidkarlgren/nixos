#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mapfile -t HOSTS < <(
  find "$REPO_DIR/hosts" -mindepth 2 -maxdepth 2 -type f -name default.nix |
  sed "s#^$REPO_DIR/hosts/##; s#/default.nix$##" | sort
)
if (( ${#HOSTS[@]} == 0 )); then
  echo "No host configurations found." >&2
  exit 1
fi

echo "Select host:"
select HOST in "${HOSTS[@]}"; do
  [[ -n "${HOST:-}" ]] && break
  echo "Invalid selection."
done

echo "Available disks:"
lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$4 == "disk"'
read -rp "Target whole disk (e.g. /dev/sda): " DISK
[[ -b "$DISK" ]] || { echo "Invalid block device." >&2; exit 1; }

echo "WARNING: ALL DATA ON $DISK WILL BE DESTROYED."
read -rp "Type exactly 'erase $DISK' to continue: " CONFIRM
[[ "$CONFIRM" == "erase $DISK" ]] || { echo "Aborted."; exit 1; }

TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_REPO"' EXIT
cp -a "$REPO_DIR/." "$TMP_REPO/"
sed -i "s#REPLACE_WITH_YOUR_DISK_ID#$DISK#g"   "$TMP_REPO/hosts/$HOST/disko.nix"

nix --extra-experimental-features "nix-command flakes" run   github:nix-community/disko/latest --   --mode destroy,format,mount --flake "$TMP_REPO#$HOST"

nixos-install --flake "$TMP_REPO#$HOST"
