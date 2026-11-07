#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$REPO_DIR"

# Require root
if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./scripts/install.sh" >&2
    exit 1
fi

# Check required commands
for cmd in lsblk nix nixos-install find sort awk sed mktemp cp readlink grep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command not found: $cmd" >&2
        exit 1
    fi
done

# Select host
echo
echo "Available host configurations:"

mapfile -t HOSTS < <(
    find hosts -mindepth 2 -maxdepth 2 \
        -type f -name configuration.nix \
        -printf '%h\n' | sed 's#^hosts/##' | sort
)

if ((${#HOSTS[@]} == 0)); then
    echo "No host configurations found."
    exit 1
fi

for i in "${!HOSTS[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${HOSTS[$i]}"
done

echo
read -r -p "Select host number: " HOST_CHOICE

if [[ ! "$HOST_CHOICE" =~ ^[0-9]+$ ]] ||
   ((HOST_CHOICE < 1 || HOST_CHOICE > ${#HOSTS[@]})); then
    echo "Invalid host selection."
    exit 1
fi

HOST="${HOSTS[$((HOST_CHOICE - 1))]}"

if [[ ! -f "hosts/$HOST/disko.nix" ]]; then
    echo "Missing hosts/$HOST/disko.nix"
    exit 1
fi

# Display all disks and their partitions
echo
echo "Available disks and partition/filesystem details:"
echo
lsblk -e7 -o NAME,PATH,SIZE,TYPE,PTTYPE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS,MODEL,SERIAL

mapfile -t DISKS < <(
    lsblk -dpnro PATH,TYPE | awk '$2 == "disk" {print $1}'
)

if ((${#DISKS[@]} == 0)); then
    echo "No disks found."
    exit 1
fi

# Select target disk
echo
echo "Select the target whole disk:"

for i in "${!DISKS[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${DISKS[$i]}"
done

echo
read -r -p "Select disk number: " DISK_CHOICE

if [[ ! "$DISK_CHOICE" =~ ^[0-9]+$ ]] ||
   ((DISK_CHOICE < 1 || DISK_CHOICE > ${#DISKS[@]})); then
    echo "Invalid disk selection."
    exit 1
fi

DISK="${DISKS[$((DISK_CHOICE - 1))]}"

# Show selected disk details
echo
echo "Selected host: $HOST"
echo "Selected disk: $DISK"
echo
lsblk -o NAME,PATH,SIZE,TYPE,PTTYPE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS,MODEL,SERIAL "$DISK"

# Explicit destructive-operation confirmation
echo
echo "WARNING: ALL DATA ON $DISK WILL BE DESTROYED."
read -r -p "Type exactly 'erase $DISK' to continue: " CONFIRM

if [[ "$CONFIRM" != "erase $DISK" ]]; then
    echo "Installation cancelled."
    exit 1
fi

# Create temporary copy and inject selected disk
TMP_BASE="$(mktemp -d)"
TMP_REPO="$TMP_BASE/repo"

cleanup() {
    rm -rf "$TMP_BASE"
}
trap cleanup EXIT

cp -a "$REPO_DIR/." "$TMP_REPO/"

# Replace the Disko placeholder in the temporary copy
PLACEHOLDER="/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID"
DISKO_CONFIG="$TMP_REPO/hosts/$HOST/disko.nix"

if ! grep -Fq "$PLACEHOLDER" "$DISKO_CONFIG"; then
    echo "Disko device placeholder not found in $DISKO_CONFIG"
    exit 1
fi

sed -i "s|$PLACEHOLDER|$DISK|g" "$DISKO_CONFIG"

# Run Disko directly from its own flake
echo
echo "==> Partitioning and mounting $DISK..."

nix --extra-experimental-features "nix-command flakes" run \
    github:nix-community/disko/latest -- \
    --mode destroy,format,mount \
    --flake "$TMP_REPO#$HOST"

# Install NixOS
echo
echo "==> Installing NixOS for $HOST..."

nixos-install --flake "$TMP_REPO#$HOST"

echo
echo "Installation complete. You can now reboot."
