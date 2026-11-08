#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

if (( EUID != 0 )); then
  die "Run this installer as root."
fi

for command in git lsblk nix nixos-enter nixos-generate-config nixos-install tar; do
  command -v "$command" >/dev/null 2>&1 || die "Required command not found: $command"
done

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
git -C "$REPO_DIR" rev-parse --show-toplevel >/dev/null 2>&1 ||
  die "Run this script from a Git checkout."
[[ "$(git -C "$REPO_DIR" rev-parse --show-toplevel)" == "$REPO_DIR" ]] ||
  die "Unexpected repository root."

mapfile -t HOSTS < <(
  find "$REPO_DIR/hosts" -mindepth 2 -maxdepth 2 -type f -name default.nix \
    -printf '%h\n' | sed "s#^$REPO_DIR/hosts/##" | sort
)
(( ${#HOSTS[@]} > 0 )) || die "No host configurations found under hosts/."

printf 'Available NixOS hosts:\n'
for index in "${!HOSTS[@]}"; do
  printf '  %d) %s\n' "$((index + 1))" "${HOSTS[$index]}"
done
read -r -p "Select a host [1-${#HOSTS[@]}]: " HOST_SELECTION
[[ "$HOST_SELECTION" =~ ^[0-9]+$ ]] || die "Invalid host selection."
(( HOST_SELECTION >= 1 && HOST_SELECTION <= ${#HOSTS[@]} )) || die "Invalid host selection."
HOST="${HOSTS[$((HOST_SELECTION - 1))]}"

DISKO_CONFIG="$REPO_DIR/hosts/$HOST/disko.nix"
[[ -f "$DISKO_CONFIG" ]] || die "Missing Disko configuration: $DISKO_CONFIG"

mapfile -t DISKS < <(lsblk -dpnro PATH,TYPE | awk '$2 == "disk" { print $1 }')
(( ${#DISKS[@]} > 0 )) || die "No disks found."

printf '\nAvailable disks and their contents:\n'
for index in "${!DISKS[@]}"; do
  printf '\n  %d) %s\n' "$((index + 1))" "${DISKS[$index]}"
  lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,SERIAL "${DISKS[$index]}"
done
read -r -p "Select the whole disk to erase [1-${#DISKS[@]}]: " DISK_SELECTION
[[ "$DISK_SELECTION" =~ ^[0-9]+$ ]] || die "Invalid disk selection."
(( DISK_SELECTION >= 1 && DISK_SELECTION <= ${#DISKS[@]} )) || die "Invalid disk selection."
DISK="${DISKS[$((DISK_SELECTION - 1))]}"
[[ -b "$DISK" ]] || die "Selected disk is not a block device: $DISK"

for attempt in 1 2 3; do
  read -r -s -p "Set the password for user arvid: " PASSWORD
  printf '\n'
  read -r -s -p "Repeat the password: " PASSWORD_CONFIRM
  printf '\n'
  if [[ -n "$PASSWORD" && "$PASSWORD" == "$PASSWORD_CONFIRM" ]]; then
    break
  fi
  unset PASSWORD PASSWORD_CONFIRM
  if (( attempt == 3 )); then
    die "Passwords were empty or did not match."
  fi
  printf 'Passwords were empty or did not match; try again.\n' >&2
done

PASSWORD_HASH="$(
  printf '%s\n' "$PASSWORD" |
    nix --extra-experimental-features "nix-command flakes" shell \
      github:NixOS/nixpkgs/nixos-26.05#whois --command \
      mkpasswd --method=yescrypt --stdin
)" || die "Could not generate a yescrypt password hash."
unset PASSWORD PASSWORD_CONFIRM
[[ "$PASSWORD_HASH" == '$y$'* ]] || die "Password hash generation returned an unexpected format."

printf '\nWARNING: Disko will destroy all data on %s.\n' "$DISK"
if grep -Fq 'type = "luks";' "$DISKO_CONFIG"; then
  printf 'Disko will ask you to enter and confirm the LUKS passphrase during formatting.\n'
fi
read -r -p "Type exactly 'erase $DISK' to continue: " CONFIRM
[[ "$CONFIRM" == "erase $DISK" ]] || die "Installation cancelled."

TMP_ROOT="$(mktemp -d)"
TMP_REPO="$TMP_ROOT/initial"
mkdir -p "$TMP_REPO"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

prepare_flake() {
  tar -C "$REPO_DIR" --exclude=.git -cf - . | tar -C "$TMP_REPO" -xf -

  local disko_config="$TMP_REPO/hosts/$HOST/disko.nix"
  local placeholder='/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID'
  local matches
  matches="$(grep -Fc "$placeholder" "$disko_config" || true)"
  [[ "$matches" == "1" ]] || die "Expected one disk ID placeholder in $disko_config, found $matches."
  sed -i "s#device = \"$placeholder\";#device = \"$DISK\";#" "$disko_config"

  if [[ ! -f "$TMP_REPO/flake.lock" ]]; then
    nix --extra-experimental-features "nix-command flakes" flake lock "$TMP_REPO"
  fi
}

prepare_flake
printf '\nPartitioning and formatting %s for host %s...\n' "$DISK" "$HOST"
nix --extra-experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount --flake "$TMP_REPO#$HOST"

install -d -m 0700 /mnt/var/lib/nixos
printf '%s\n' "$PASSWORD_HASH" > /mnt/var/lib/nixos/arvid-password
chmod 0400 /mnt/var/lib/nixos/arvid-password
unset PASSWORD_HASH

nixos-generate-config --root /mnt --no-filesystems
GENERATED_HARDWARE=/mnt/etc/nixos/hardware-configuration.nix
[[ -s "$GENERATED_HARDWARE" ]] || die "Hardware configuration was not generated at $GENERATED_HARDWARE."
cp "$GENERATED_HARDWARE" "$TMP_REPO/hosts/$HOST/hardware.nix"
nix --extra-experimental-features "nix-command flakes" eval --raw \
  "$TMP_REPO#nixosConfigurations.$HOST.config.system.build.toplevel.drvPath" >/dev/null

TARGET_REPO=/mnt/home/arvid/nixos
mkdir -p /mnt/home/arvid
[[ ! -e "$TARGET_REPO" ]] || die "Target repository path already exists: $TARGET_REPO"
cp -a "$REPO_DIR" "$TARGET_REPO"
cp "$GENERATED_HARDWARE" "$TARGET_REPO/hosts/$HOST/hardware.nix"
if [[ ! -f "$TARGET_REPO/flake.lock" ]]; then
  cp "$TMP_REPO/flake.lock" "$TARGET_REPO/flake.lock"
fi

printf '\nInstalling NixOS host %s...\n' "$HOST"
nixos-install --root /mnt --flake "$TMP_REPO#$HOST" --no-root-passwd
nixos-enter --root /mnt -- chown -R arvid:users /home/arvid/nixos
printf 'Generated hardware config is saved at /home/arvid/nixos/hosts/%s/hardware.nix.\n' "$HOST"
printf 'After reboot, review and commit/push that file so the hardware config is tracked in Git.\n'
