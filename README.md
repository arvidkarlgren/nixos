# NixOS COSMIC configuration

This repository defines a `desktop` host for x86_64 UEFI systems, using
COSMIC, Btrfs, Disko, Git, SSH, and xrdp.

## Before installing

1. Boot the NixOS installer in UEFI mode.
2. Obtain this repository in the live environment.
3. Edit `hosts/desktop/disko.nix` and replace
   `REPLACE_WITH_YOUR_DISK_ID` with the correct whole-disk path from
   `/dev/disk/by-id/`.
4. Verify the disk ID carefully. The install script destroys and repartitions
   the selected disk.

Inspect disk IDs with:

```bash
ls -l /dev/disk/by-id/
```

## Install

From the repository root:

```bash
chmod +x scripts/install.sh
sudo ./scripts/install.sh desktop
```

The host argument selects the flake configuration. Additional hosts need
entries in `flake.nix` and corresponding directories under `hosts/`.

The script asks for explicit confirmation before running Disko.

## Installed user

The configured user is `arvid`. The initial password is `test`, retained
from the earlier test configuration. Change it after installation:

```bash
passwd
```

The password is configured as a plaintext initial password for testing;
do not use it as a long-term credential.

## Git repository clone

During system activation, the configuration attempts to clone
`https://github.com/arvidkarlgren/nixos.git` into `/home/arvid/nixos` if
that path does not already contain a Git repository. Git is also installed
as a system package.

## Remote desktop

xrdp is enabled and TCP port 3389 is opened. xrdp normally creates a separate
X11 session; it does not automatically share the active COSMIC Wayland
session. A compatible X11 desktop/session setup may be needed for a complete
remote graphical desktop.

## Storage layout

Disko creates a 1 GiB EFI system partition and a Btrfs partition containing:

- `@` mounted at `/`
- `@home` mounted at `/home`
- `@nix` mounted at `/nix`
- `@log` mounted at `/var/log`
- `@snapshots` mounted at `/.snapshots`
- `@swap` mounted at `/.swapvol`

All Btrfs subvolumes share free space in the same filesystem.
