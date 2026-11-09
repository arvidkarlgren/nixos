#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

if (( EUID != 0 )); then
  die "Run this installer as root."
fi

for command in cryptsetup git install lsblk mount nix nixos-enter nixos-generate-config nixos-install realpath umount; do
  command -v "$command" >/dev/null 2>&1 || die "Required command not found: $command"
done

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
repo_git() {
  git -C "$REPO_DIR" -c "safe.directory=$REPO_DIR" "$@"
}
repo_git rev-parse --show-toplevel >/dev/null 2>&1 ||
  die "Run this script from a cloned Git repository."
[[ "$(repo_git rev-parse --show-toplevel)" == "$REPO_DIR" ]] ||
  die "Unexpected repository root."
[[ -f "$REPO_DIR/flake.nix" && -f "$REPO_DIR/secrets/common.yaml" ]] ||
  die "The repository is missing flake.nix or secrets/common.yaml."

ORIGIN_URL="$(repo_git remote get-url origin)" ||
  die "The source checkout has no origin remote."
case "$ORIGIN_URL" in
  git@github.com:*)
    SSH_ORIGIN="$ORIGIN_URL"
    ;;
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
    die "Unsupported GitHub origin URL; cannot configure the installed checkout for SSH pushes."
    ;;
esac
[[ "$SSH_ORIGIN" =~ ^git@github\.com:[[:alnum:]_.-]+/[[:alnum:]_.-]+(\.git)?$ ]] ||
  die "Could not derive a valid GitHub SSH URL from origin: $ORIGIN_URL"

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
[[ -f "$DISKO_CONFIG" ]] || die "Missing Disko configuration for host $HOST."

printf '\nAvailable disks:\n'
mapfile -t DISKS < <(lsblk -dpnro PATH,TYPE | awk '$2 == "disk" { print $1 }')
(( ${#DISKS[@]} > 0 )) || die "No disks found."
for index in "${!DISKS[@]}"; do
  read -r DISK_PATH DISK_MODEL < <(
    lsblk -dnro PATH,MODEL "${DISKS[$index]}" | sed 's/[[:space:]]*$//'
  )
  printf '  %d) %s  %s\n' "$((index + 1))" "$DISK_PATH" "${DISK_MODEL:-Unknown model}"
done
read -r -p "Select the whole target disk [1-${#DISKS[@]}]: " DISK_SELECTION
[[ "$DISK_SELECTION" =~ ^[0-9]+$ ]] || die "Invalid disk selection."
(( DISK_SELECTION >= 1 && DISK_SELECTION <= ${#DISKS[@]} )) || die "Invalid disk selection."
DISK="${DISKS[$((DISK_SELECTION - 1))]}"
printf '\nPartitions and filesystem types on %s:\n' "$DISK"
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL "$DISK"
printf '\nWARNING: Disko will destroy all data on %s.\n' "$DISK"
read -r -p "Type exactly 'erase $DISK' to continue: " CONFIRM
[[ "$CONFIRM" == "erase $DISK" ]] || die "Installation cancelled."

printf '\nAvailable partitions and block devices for the encrypted age-key USB:\n'
lsblk -fp -o NAME,SIZE,FSTYPE,LABEL,TYPE,MOUNTPOINTS,MODEL
read -r -p "Enter the LUKS USB partition path: " USB_DEVICE
[[ "$USB_DEVICE" =~ ^/dev/[[:alnum:]_./+-]+$ && -b "$USB_DEVICE" ]] ||
  die "Not a valid USB block device path: $USB_DEVICE"
[[ "$(lsblk -dnro TYPE "$USB_DEVICE")" == "part" ]] ||
  die "Select the USB partition containing the LUKS filesystem."
cryptsetup isLuks "$USB_DEVICE" ||
  die "The selected USB partition is not recognized as a LUKS device."
USB_PARENT="$(lsblk -dnro PKNAME "$USB_DEVICE")"
[[ -n "$USB_PARENT" && "/dev/$USB_PARENT" != "$DISK" ]] ||
  die "The age-key USB must be a partition on a disk other than the target disk."
read -r -p "Path to your age identity file on the unlocked USB: " USB_KEY_PATH
[[ "$USB_KEY_PATH" != /* && "$USB_KEY_PATH" != *".."* && -n "$USB_KEY_PATH" ]] ||
  die "Enter a relative path on the USB without '..' components."

HAS_LUKS="$(grep -Fq 'type = "luks";' "$DISKO_CONFIG" && printf yes || printf no)"
if [[ "$HAS_LUKS" == yes ]]; then
  for attempt in 1 2 3; do
    read -r -s -p "Set the target disk LUKS passphrase: " LUKS_PASSWORD
    printf '\n'
    read -r -s -p "Repeat the target disk LUKS passphrase: " LUKS_PASSWORD_CONFIRM
    printf '\n'
    if [[ -n "$LUKS_PASSWORD" && "$LUKS_PASSWORD" == "$LUKS_PASSWORD_CONFIRM" ]]; then
      break
    fi
    unset LUKS_PASSWORD LUKS_PASSWORD_CONFIRM
    if (( attempt == 3 )); then
      die "LUKS passphrases were empty or did not match."
    fi
    printf 'Passphrases were empty or did not match; try again.\n' >&2
  done
fi

RUN_ROOT="$(mktemp -d /run/nixos-install.XXXXXX)"
chmod 0700 "$RUN_ROOT"
TMP_ROOT="$RUN_ROOT/work"
mkdir -m 0700 "$TMP_ROOT"
PERSONAL_KEY="$RUN_ROOT/personal-age-key"
USB_MAPPER="nixos-age-key-usb"
USB_MOUNT="$RUN_ROOT/usb"
USB_OPEN=false
USB_MOUNTED=false
cleanup() {
  if [[ "$USB_MOUNTED" == true ]]; then
    umount "$USB_MOUNT" || true
  fi
  if [[ "$USB_OPEN" == true ]]; then
    cryptsetup close "$USB_MAPPER" || true
  fi
  rm -rf -- "$RUN_ROOT"
}
trap cleanup EXIT

mkdir -m 0700 "$USB_MOUNT"
cryptsetup open --type luks --readonly "$USB_DEVICE" "$USB_MAPPER"
USB_OPEN=true
mount -o ro,nodev,nosuid,noexec "/dev/mapper/$USB_MAPPER" "$USB_MOUNT"
USB_MOUNTED=true
USB_KEY_SOURCE="$USB_MOUNT/$USB_KEY_PATH"
[[ -f "$USB_KEY_SOURCE" ]] || die "Age identity file not found on the USB at the requested path."
USB_KEY_SOURCE="$(realpath -e -- "$USB_KEY_SOURCE")"
[[ "$USB_KEY_SOURCE" == "$USB_MOUNT/"* ]] ||
  die "The requested age identity resolves outside the mounted USB."
install -m 0600 "$USB_KEY_SOURCE" "$PERSONAL_KEY"
umount "$USB_MOUNT"
USB_MOUNTED=false
cryptsetup close "$USB_MAPPER"
USB_OPEN=false

if [[ "$HAS_LUKS" == yes ]]; then
  umask 077
  printf '%s' "$LUKS_PASSWORD" > "$RUN_ROOT/luks-password"
  chmod 0600 "$RUN_ROOT/luks-password"
  unset LUKS_PASSWORD LUKS_PASSWORD_CONFIRM
fi

NIXPKGS_REF="github:NixOS/nixpkgs/nixos-26.05"
BOOTSTRAP_PACKAGES=(
  "$NIXPKGS_REF#age"
  "$NIXPKGS_REF#sops"
  "$NIXPKGS_REF#yq-go"
)
run_tool() {
  nix --extra-experimental-features "nix-command flakes" shell \
    "${BOOTSTRAP_PACKAGES[@]}" --command "$@"
}

PERSONAL_AGE_PUBLIC="$(run_tool age-keygen -y "$PERSONAL_KEY")" ||
  die "Could not read the public recipient from the USB age identity."
[[ "$PERSONAL_AGE_PUBLIC" == age1* ]] ||
  die "The USB identity did not produce a valid age recipient."
export PERSONAL_AGE_PUBLIC
SOPS_FILE="$REPO_DIR/secrets/common.yaml"

umask 077
PERSONAL_PASSWORD_HASH="$TMP_ROOT/personal-password-hash"
PERSONAL_SSH_KEY="$TMP_ROOT/personal-ssh-key"
run_tool env "SOPS_AGE_KEY_FILE=$PERSONAL_KEY" sops decrypt \
  --extract '["passwords"]["arvid"]' "$SOPS_FILE" > "$PERSONAL_PASSWORD_HASH" ||
  die "Could not decrypt passwords.arvid with the personal age key."
run_tool env "SOPS_AGE_KEY_FILE=$PERSONAL_KEY" sops decrypt \
  --extract '["ssh"]["arvid"]' "$SOPS_FILE" > "$PERSONAL_SSH_KEY" ||
  die "Could not decrypt ssh.arvid with the personal age key."
[[ -s "$PERSONAL_PASSWORD_HASH" ]] || die "The SOPS password hash for arvid is empty."
grep -Eq '^\$(y|6|5|2[aby])\$' "$PERSONAL_PASSWORD_HASH" ||
  die "The SOPS password for arvid does not look like a supported password hash."
grep -q '^-----BEGIN .* PRIVATE KEY-----$' "$PERSONAL_SSH_KEY" ||
  die "The SOPS ssh.arvid secret is empty or is not an OpenSSH-compatible private key."
unset PERSONAL_PASSWORD_HASH PERSONAL_SSH_KEY

if [[ ! -f "$REPO_DIR/.sops.yaml" ]]; then
  cat > "$REPO_DIR/.sops.yaml" <<'EOF'
creation_rules:
  - path_regex: 'secrets/.*\.yaml$'
    age: ""
EOF
fi

SOPS_RULE_REGEX='secrets/.*\.yaml$'
export SOPS_RULE_REGEX
RULE_COUNT="$(run_tool yq -r \
  '[.creation_rules[]? | select(.path_regex == strenv(SOPS_RULE_REGEX))] | length' \
  "$REPO_DIR/.sops.yaml")"
[[ "$RULE_COUNT" =~ ^[0-9]+$ ]] || die "Could not parse .sops.yaml creation rules."
if [[ "$RULE_COUNT" == 0 ]]; then
  run_tool yq -i \
    '.creation_rules = (.creation_rules // []) | .creation_rules += [{"path_regex": strenv(SOPS_RULE_REGEX), "age": ""}]' \
    "$REPO_DIR/.sops.yaml"
elif [[ "$RULE_COUNT" != 1 ]]; then
  die "Expected exactly one .sops.yaml rule for $SOPS_RULE_REGEX; found $RULE_COUNT."
fi

MACHINE_KEY=/mnt/var/lib/sops-nix/key.txt

prepare_stage() {
  local stage="$1"
  mkdir -p "$stage"
  tar -C "$REPO_DIR" --exclude=.git -cf - . | tar -C "$stage" -xf -
  local staged_disko="$stage/hosts/$HOST/disko.nix"
  local placeholder='/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID'
  local matches
  matches="$(grep -Fc "$placeholder" "$staged_disko" || true)"
  [[ "$matches" == "1" ]] || die "Expected one disk ID placeholder in $staged_disko, found $matches."
  sed -i "s#device = \"$placeholder\";#device = \"$DISK\";#" "$staged_disko"
  if [[ "$HAS_LUKS" == yes ]]; then
    local replacements
    replacements="$(grep -Fc 'askPassword = true;' "$staged_disko" || true)"
    [[ "$replacements" == "1" ]] ||
      die "Expected one interactive LUKS password setting in $staged_disko."
    sed -i "s#askPassword = true;#passwordFile = \"$RUN_ROOT/luks-password\";#" "$staged_disko"
  fi
}

INITIAL_STAGE="$TMP_ROOT/disko-flake"
prepare_stage "$INITIAL_STAGE"
if [[ ! -f "$INITIAL_STAGE/flake.lock" ]]; then
  nix --extra-experimental-features "nix-command flakes" flake lock "$INITIAL_STAGE"
  cp "$INITIAL_STAGE/flake.lock" "$REPO_DIR/flake.lock"
fi

printf '\nPartitioning and formatting %s for host %s...\n' "$DISK" "$HOST"
nix --extra-experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount --yes-wipe-all-disks --flake "$INITIAL_STAGE#$HOST"

install -d -o root -g root -m 0700 /mnt/var/lib/sops-nix
umask 077
run_tool age-keygen -pq -o "$MACHINE_KEY" > "$TMP_ROOT/age-keygen.log" ||
  die "Could not generate the machine age key."
chmod 0600 "$MACHINE_KEY"
MACHINE_AGE_PUBLIC="$(run_tool age-keygen -y "$MACHINE_KEY")" ||
  die "Could not derive the machine age public key."
[[ "$MACHINE_AGE_PUBLIC" == age1pq1* ]] ||
  die "Generated machine age key is not a valid post-quantum recipient."
export MACHINE_AGE_PUBLIC

HAS_KEY_GROUPS="$(run_tool yq -r \
  '.creation_rules[] | select(.path_regex == strenv(SOPS_RULE_REGEX)) | has("key_groups")' \
  "$REPO_DIR/.sops.yaml")"
if [[ "$HAS_KEY_GROUPS" == true ]]; then
  run_tool yq -i \
    '(.creation_rules[] | select(.path_regex == strenv(SOPS_RULE_REGEX)) | .key_groups[]) |= (.age = ((.age // []) + [strenv(PERSONAL_AGE_PUBLIC), strenv(MACHINE_AGE_PUBLIC)] | unique))' \
    "$REPO_DIR/.sops.yaml"
else
  run_tool yq -i \
    'explode(.) | (.creation_rules[] | select(.path_regex == strenv(SOPS_RULE_REGEX))) |= (.age = (((.age // "" | split(",") | map(select(. != ""))) + [strenv(PERSONAL_AGE_PUBLIC), strenv(MACHINE_AGE_PUBLIC)] | unique | join(","))))' \
    "$REPO_DIR/.sops.yaml"
fi
run_tool yq -i 'explode(.)' "$REPO_DIR/.sops.yaml"

(
  cd "$REPO_DIR"
  run_tool env "SOPS_AGE_KEY_FILE=$PERSONAL_KEY" sops updatekeys --yes secrets/common.yaml
)
run_tool env "SOPS_AGE_KEY_FILE=$PERSONAL_KEY" sops decrypt \
  --output /dev/null "$SOPS_FILE" ||
  die "SOPS validation failed with the personal age key."
run_tool env "SOPS_AGE_KEY_FILE=$MACHINE_KEY" sops decrypt \
  --output /dev/null "$SOPS_FILE" ||
  die "SOPS validation failed with the generated machine age key."
run_tool env "SOPS_AGE_KEY_FILE=$MACHINE_KEY" sops decrypt \
  --extract '["passwords"]["arvid"]' "$SOPS_FILE" > "$TMP_ROOT/machine-password-hash" ||
  die "The generated machine key cannot decrypt passwords.arvid."
run_tool env "SOPS_AGE_KEY_FILE=$MACHINE_KEY" sops decrypt \
  --extract '["ssh"]["arvid"]' "$SOPS_FILE" > "$TMP_ROOT/machine-ssh-key" ||
  die "The generated machine key cannot decrypt ssh.arvid."
[[ -s "$TMP_ROOT/machine-password-hash" ]] || die "The machine password hash is empty."
grep -Eq '^\$(y|6|5|2[aby])\$' "$TMP_ROOT/machine-password-hash" ||
  die "The machine password secret is not a supported password hash."
grep -q '^-----BEGIN .* PRIVATE KEY-----$' "$TMP_ROOT/machine-ssh-key" ||
  die "The machine SSH private key secret is empty or invalid."

nixos-generate-config --root /mnt --no-filesystems
GENERATED_HARDWARE=/mnt/etc/nixos/hardware-configuration.nix
[[ -s "$GENERATED_HARDWARE" ]] || die "Hardware configuration was not generated."
cp "$GENERATED_HARDWARE" "$REPO_DIR/hosts/$HOST/hardware.nix"

FINAL_STAGE="$TMP_ROOT/install-flake"
prepare_stage "$FINAL_STAGE"
cp "$REPO_DIR/flake.lock" "$FINAL_STAGE/flake.lock"
nix --extra-experimental-features "nix-command flakes" eval --raw \
  "$FINAL_STAGE#nixosConfigurations.$HOST.config.system.build.toplevel.drvPath" >/dev/null

TARGET_REPO=/mnt/home/arvid/nixos
mkdir -p /mnt/home/arvid
[[ ! -e "$TARGET_REPO" ]] || die "Target repository path already exists: $TARGET_REPO"
cp -a "$REPO_DIR" "$TARGET_REPO"
git -C "$TARGET_REPO" -c "safe.directory=$TARGET_REPO" remote set-url origin "$SSH_ORIGIN"
nixos-install --root /mnt --flake "$FINAL_STAGE#$HOST" --no-root-passwd
nixos-enter --root /mnt -- chown -R arvid:users /home/arvid/nixos

printf '\nInstalled host %s.\n' "$HOST"
printf 'The machine age key is at /var/lib/sops-nix/key.txt; the personal age key was removed from /run.\n'
printf 'The generated hardware config and updated SOPS recipients are in /home/arvid/nixos for review and commit.\n'
printf 'The installed repository origin is configured for SSH: %s\n' "$SSH_ORIGIN"
printf 'After reboot, verify the SOPS password and SSH key secrets, then commit and push the generated changes.\n'
