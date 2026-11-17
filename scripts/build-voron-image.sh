#!/usr/bin/env bash
set -euo pipefail
umask 077

if (( $# > 1 )); then
  printf 'Usage: %s [OUTPUT.img]\n' "$0" >&2
  exit 1
fi

if [[ "$(uname -s)" != Linux ]]; then
  printf 'This script must run on Linux.\n' >&2
  exit 1
fi

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
HOST_SECRETS="$REPO_DIR/secrets/hosts/voron.yaml"
PERSONAL_KEY="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
NIXPKGS_REF="github:NixOS/nixpkgs/nixos-26.05"
OUTPUT="${1:-$HOME/voron-nixos.img}"
NIX_FLAGS=(--extra-experimental-features "nix-command flakes")
BOOTSTRAP_PACKAGES=(
  "$NIXPKGS_REF#age"
  "$NIXPKGS_REF#sops"
  "$NIXPKGS_REF#yq-go"
)

if [[ ! -f "$PERSONAL_KEY" ]]; then
  printf 'Personal age identity not found at %s.\n' "$PERSONAL_KEY" >&2
  printf 'Set SOPS_AGE_KEY_FILE or install the personal key from personal.yaml first.\n' >&2
  exit 1
fi

if [[ ! -f "$HOST_SECRETS" ]]; then
  printf 'Voron secrets file not found at %s.\n' "$HOST_SECRETS" >&2
  exit 1
fi

for command in nix sudo tar find losetup mount umount; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

OUTPUT_DIR="$(dirname -- "$OUTPUT")"
OUTPUT_NAME="$(basename -- "$OUTPUT")"
mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd -P)"
OUTPUT="$OUTPUT_DIR/$OUTPUT_NAME"

case "$OUTPUT" in
  "$REPO_DIR"|"$REPO_DIR"/*)
    printf "Choose an output path outside the repository; the image contains Voron's private age identity.\n" >&2
    exit 1
    ;;
esac

if [[ -e "$OUTPUT" || -L "$OUTPUT" ]]; then
  printf 'Output already exists: %s\n' "$OUTPUT" >&2
  exit 1
fi

# Request sudo credentials before building the image.
sudo -v

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/nixos-voron-image.XXXXXX")"
chmod 0700 "$TMP_ROOT"
WORK_IMAGE="$(mktemp "$OUTPUT_DIR/.voron-image.XXXXXX")"
chmod 0600 "$WORK_IMAGE"
ROOT_MOUNT="$TMP_ROOT/root"
mkdir -m 0700 "$ROOT_MOUNT"
LOOP_DEVICE=""
MOUNTED=false

cleanup() {
  local status=$?
  local cleanup_safe=true
  trap - EXIT

  if [[ "$MOUNTED" == true ]]; then
    if ! sudo umount "$ROOT_MOUNT"; then
      printf 'Failed to unmount the image root filesystem at %s.\n' "$ROOT_MOUNT" >&2
      status=1
      cleanup_safe=false
    else
      MOUNTED=false
    fi
  fi
  if [[ -n "$LOOP_DEVICE" && "$MOUNTED" == false ]]; then
    if ! sudo losetup --detach "$LOOP_DEVICE"; then
      printf 'Failed to detach loop device %s.\n' "$LOOP_DEVICE" >&2
      status=1
      cleanup_safe=false
    else
      LOOP_DEVICE=""
    fi
  fi

  if [[ "$cleanup_safe" == true ]]; then
    if [[ -n "$WORK_IMAGE" ]]; then
      rm -f -- "$WORK_IMAGE"
    fi
    rm -rf -- "$TMP_ROOT"
  else
    printf 'Temporary image data was retained for safe manual cleanup: %s\n' "$TMP_ROOT" >&2
    if [[ -n "$WORK_IMAGE" ]]; then
      printf 'Temporary image: %s\n' "$WORK_IMAGE" >&2
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

run_tool() {
  nix "${NIX_FLAGS[@]}" shell "${BOOTSTRAP_PACKAGES[@]}" --command "$@"
}

MACHINE_KEY="$TMP_ROOT/machine-age-key"
SOPS_AGE_KEY_FILE="$PERSONAL_KEY" run_tool sops decrypt \
  --extract '["machine_age_key"]' "$HOST_SECRETS" > "$MACHINE_KEY"
chmod 0600 "$MACHINE_KEY"
MACHINE_RECIPIENT="$(run_tool age-keygen -y "$MACHINE_KEY")"
FILE_RECIPIENTS="$(run_tool yq -r '.sops.age[].recipient' "$HOST_SECRETS")"
if ! grep -Fxq -- "$MACHINE_RECIPIENT" <<< "$FILE_RECIPIENTS"; then
  printf 'Voron machine identity does not match a recipient in %s.\n' "$HOST_SECRETS" >&2
  exit 1
fi

# Build from a non-Git staging copy so untracked host configuration is included.
FLAKE_STAGE="$TMP_ROOT/flake"
mkdir -m 0700 "$FLAKE_STAGE"
tar -C "$REPO_DIR" --exclude=.git -cf - . | tar -C "$FLAKE_STAGE" -xf -

BUILD_LINK="$TMP_ROOT/build"
if ! nix "${NIX_FLAGS[@]}" build \
  "$FLAKE_STAGE#nixosConfigurations.voron.config.system.build.sdImage" \
  --out-link "$BUILD_LINK"; then
  printf 'If Nix reports that aarch64-linux is unsupported, configure QEMU/binfmt emulation or an aarch64 remote builder.\n' >&2
  exit 1
fi

mapfile -t IMAGES < <(find "$BUILD_LINK/sd-image" -maxdepth 1 -type f -name '*.img' -print)
if (( ${#IMAGES[@]} != 1 )); then
  printf 'Expected one raw .img image in %s, found %s.\n' \
    "$BUILD_LINK/sd-image" "${#IMAGES[@]}" >&2
  exit 1
fi

cp -- "${IMAGES[0]}" "$WORK_IMAGE"
chmod 0600 "$WORK_IMAGE"

# The SD image has a FAT firmware partition followed by an ext4 root partition.
LOOP_DEVICE="$(sudo losetup --find --show --partscan "$WORK_IMAGE")"
ROOT_PARTITION="${LOOP_DEVICE}p2"
for _ in {1..50}; do
  [[ -b "$ROOT_PARTITION" ]] && break
  sleep 0.1
done
if [[ ! -b "$ROOT_PARTITION" ]]; then
  printf 'Root partition did not appear for loop device %s.\n' "$LOOP_DEVICE" >&2
  exit 1
fi

sudo mount "$ROOT_PARTITION" "$ROOT_MOUNT"
MOUNTED=true
sudo install -d -o root -g root -m 0700 "$ROOT_MOUNT/var/lib/sops-nix"
sudo install -o root -g root -m 0600 "$MACHINE_KEY" \
  "$ROOT_MOUNT/var/lib/sops-nix/key.txt"
sync
sudo umount "$ROOT_MOUNT"
MOUNTED=false
sudo losetup --detach "$LOOP_DEVICE"
LOOP_DEVICE=""

mv --no-clobber -- "$WORK_IMAGE" "$OUTPUT"
if [[ -e "$WORK_IMAGE" ]]; then
  printf 'Output appeared while the image was being built; refusing to overwrite %s.\n' \
    "$OUTPUT" >&2
  exit 1
fi
WORK_IMAGE=""

printf 'Built Voron image: %s\n' "$OUTPUT"
printf "The image includes Voron's machine age identity and is mode 0600; keep it private.\n"
