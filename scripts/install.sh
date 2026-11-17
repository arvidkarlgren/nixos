#!/usr/bin/env bash
set -euo pipefail

# Require the host name and target disk.
if (( $# != 2 )); then
  printf 'Usage: %s HOST DISK\n' "$0" >&2
  exit 1
fi

HOST="$1"
DISK="$2"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DISKO_CONFIG="$REPO_DIR/hosts/$HOST/disko.nix"
HOST_SECRETS="$REPO_DIR/secrets/hosts/$HOST.yaml"
PERSONAL_KEY=/root/age.key
NIXPKGS_REF="github:NixOS/nixpkgs/nixos-26.05"
BOOTSTRAP_PACKAGES=(
  "$NIXPKGS_REF#age"
  "$NIXPKGS_REF#sops"
  "$NIXPKGS_REF#yq-go"
)

# Check required local inputs before starting.
if [[ ! -f "$PERSONAL_KEY" ]]; then
  printf 'Age identity not found at %s. Place your key there before running the installer.\n' \
    "$PERSONAL_KEY" >&2
  exit 1
fi

if [[ ! "$HOST" =~ ^[[:alnum:]_-]+$ || ! -f "$DISKO_CONFIG" ]]; then
  printf 'Unknown host: %s\n' "$HOST" >&2
  exit 1
fi

if [[ ! -f "$HOST_SECRETS" ]]; then
  printf 'Pre-provisioned host secrets not found at %s. Add and encrypt this host file before cloning the repository.\n' \
    "$HOST_SECRETS" >&2
  exit 1
fi

# Run age and SOPS from the pinned Nixpkgs tools.
run_tool() {
  nix --extra-experimental-features "nix-command flakes" shell \
    "${BOOTSTRAP_PACKAGES[@]}" --command "$@"
}

# Collect the disk-encryption passphrase when this host uses LUKS.
if grep -q 'type = "luks";' "$DISKO_CONFIG"; then
  read -r -s -p "Set the target disk LUKS passphrase: " LUKS_PASSWORD
  printf '\n'
  HAS_LUKS=true
else
  HAS_LUKS=false
fi

# Confirm the supplied target is a whole disk before wiping it.
if [[ ! -b "$DISK" || "$(lsblk -dnro TYPE "$DISK")" != disk ]]; then
  printf 'Target must be a whole disk block device: %s\n' "$DISK" >&2
  exit 1
fi

printf 'Partitions and filesystem types on %s:\n' "$DISK"
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL "$DISK"
printf 'WARNING: Disko will destroy all data on %s.\n' "$DISK"
read -r -p "Type exactly 'erase $DISK' to continue: " CONFIRM
if [[ "$CONFIRM" != "erase $DISK" ]]; then
  printf 'Installation cancelled.\n' >&2
  exit 1
fi

# Keep temporary files private and remove them when the script exits.
RUN_ROOT="$(mktemp -d /run/nixos-install.XXXXXX)"
chmod 0700 "$RUN_ROOT"
TMP_ROOT="$RUN_ROOT/work"
mkdir -m 0700 "$TMP_ROOT"
trap 'rm -rf -- "$RUN_ROOT"' EXIT

if [[ "$HAS_LUKS" == true ]]; then
  umask 077
  printf '%s' "$LUKS_PASSWORD" > "$RUN_ROOT/luks-password"
  unset LUKS_PASSWORD
fi

# Decrypt and validate the machine identity before formatting the target disk.
SOPS_AGE_KEY_FILE="$PERSONAL_KEY" run_tool sops decrypt \
  --extract '["machine_age_key"]' "$HOST_SECRETS" > "$TMP_ROOT/machine-age-key"
run_tool age-keygen -y "$TMP_ROOT/machine-age-key" >/dev/null

# Preserve an SSH-compatible origin URL for the installed checkout.
ORIGIN_URL="$(git -C "$REPO_DIR" -c "safe.directory=$REPO_DIR" remote get-url origin)"
case "$ORIGIN_URL" in
  https://github.com/*)
    SSH_ORIGIN="git@github.com:${ORIGIN_URL#https://github.com/}"
    ;;
  http://github.com/*)
    SSH_ORIGIN="git@github.com:${ORIGIN_URL#http://github.com/}"
    ;;
  ssh://git@github.com/*)
    SSH_ORIGIN="git@github.com:${ORIGIN_URL#ssh://git@github.com/}"
    ;;
  *)
    SSH_ORIGIN="$ORIGIN_URL"
    ;;
esac

# Stage the repository with this host's disk and passphrase settings.
prepare_stage() {
  local stage="$1"
  mkdir -p "$stage"
  tar -C "$REPO_DIR" --exclude=.git -cf - . | tar -C "$stage" -xf -
  sed -i \
    "s#device = \"/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID\";#device = \"$DISK\";#" \
    "$stage/hosts/$HOST/disko.nix"
  if [[ "$HAS_LUKS" == true ]]; then
    sed -i \
      "s#askPassword = true;#passwordFile = \"$RUN_ROOT/luks-password\";#" \
      "$stage/hosts/$HOST/disko.nix"
  fi
}

# Lock the staged flake before using it for disk setup.
INITIAL_STAGE="$TMP_ROOT/disko-flake"
prepare_stage "$INITIAL_STAGE"
if [[ ! -f "$INITIAL_STAGE/flake.lock" ]]; then
  nix --extra-experimental-features "nix-command flakes" flake lock "$INITIAL_STAGE"
  cp "$INITIAL_STAGE/flake.lock" "$REPO_DIR/flake.lock"
fi

# Partition, format, and mount the target disk.
printf 'Partitioning and formatting %s for host %s...\n' "$DISK" "$HOST"
nix --extra-experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount --yes-wipe-all-disks --flake "$INITIAL_STAGE#$HOST"

# Install the pre-provisioned machine identity for sops-nix.
MACHINE_KEY=/mnt/var/lib/sops-nix/key.txt
install -d -o root -g root -m 0700 /mnt/var/lib/sops-nix
umask 077
install -m 0600 "$TMP_ROOT/machine-age-key" "$MACHINE_KEY"

# Generate host hardware configuration and stage the final install flake.
nixos-generate-config --root /mnt --no-filesystems
cp /mnt/etc/nixos/hardware-configuration.nix "$REPO_DIR/hosts/$HOST/hardware.nix"

FINAL_STAGE="$TMP_ROOT/install-flake"
prepare_stage "$FINAL_STAGE"
cp "$REPO_DIR/flake.lock" "$FINAL_STAGE/flake.lock"

# Copy the configured repository and install the selected host.
TARGET_REPO=/mnt/home/arvid/nixos
mkdir -p /mnt/home/arvid
if [[ -e "$TARGET_REPO" ]]; then
  printf 'Target repository path already exists: %s\n' "$TARGET_REPO" >&2
  exit 1
fi
cp -a "$REPO_DIR" "$TARGET_REPO"
git -C "$TARGET_REPO" -c "safe.directory=$TARGET_REPO" remote set-url origin "$SSH_ORIGIN"
nixos-install --root /mnt --flake "$FINAL_STAGE#$HOST" --no-root-passwd
nixos-enter --root /mnt -- chown -R arvid:users /home/arvid

printf 'Installed host %s.\n' "$HOST"
printf 'The machine age key is at /var/lib/sops-nix/key.txt.\n'
printf 'Review and commit the generated hardware config in /home/arvid/nixos.\n'
