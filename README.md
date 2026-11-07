# Multi-host NixOS configuration

A shared baseline for `desktop` and `laptop`, with host-specific additions.

## Layout

- `flake.nix`: defines the hosts and assembles each system.
- `common/`: shared NixOS configuration, split by broad area.
- `hosts/<host>/`: hardware, Disko layout, and host-specific additions.
- `home/`: reserved for Home Manager and dotfiles; not integrated yet.
- `secrets/`: reserved for SOPS/age; not integrated yet.
- `scripts/install.sh`: interactive host/disk installer.

## Before use

1. Review both Disko files and replace the disk placeholder, or use the installer.
2. Populate laptop hardware settings from `nixos-generate-config --show-hardware-config`.
3. Replace the temporary `initialPassword` and review passwordless sudo.
4. Review whether Sunshine and Steam should be enabled on both hosts.
5. The current Disko layout is unencrypted Btrfs. LUKS is not implemented.
6. Home Manager and SOPS/age are not implemented.

## Rebuild

```bash
sudo nixos-rebuild switch --flake .#desktop
sudo nixos-rebuild switch --flake .#laptop
```

## Initialize Git and lock dependencies

```bash
git init
git add .
nix flake lock
git add flake.lock
git commit -m "Initial NixOS configuration"
```

Commit `flake.lock` to pin dependency revisions.

## Install

Boot the NixOS installer, access this repository, then run:

```bash
bash scripts/install.sh
```

The script formats the selected disk after explicit confirmation. Do not run it
against a disk containing data you want to keep.
