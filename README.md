# NixOS COSMIC Proxmox test configuration

Minimal NixOS configuration with Flakes, Disko, Btrfs and COSMIC.

## Before installing

1. Configure the Proxmox VM to use OVMF (UEFI).
2. Add a Proxmox EFI Disk.
3. Boot the NixOS installer and connect to the network.
4. Clone this repository (or copy this directory to the installer).
5. Find the target disk ID:

   ```bash
   ls -l /dev/disk/by-id/
   ```

6. Edit `hosts/desktop/disko.nix` and replace
   `REPLACE_WITH_YOUR_DISK_ID` with the correct whole-disk ID.
7. Verify the target disk carefully. Disko's destroy mode erases it.

## Partition and mount

From the repository root:

```bash
sudo nix run github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --flake .#desktop
```

Check the resulting mounts:

```bash
lsblk -f
findmnt -R /mnt
```

## Install

```bash
sudo nixos-install --flake .#desktop
```

Reboot, remove the installer ISO, and boot from the virtual disk.

## Included layout

- 1 GiB FAT32 EFI partition mounted at `/boot`
- Remaining disk as Btrfs
- `@` mounted at `/`
- `@home` mounted at `/home`
- `@nix` mounted at `/nix`
- `@log` mounted at `/var/log`
- `@snapshots` mounted at `/.snapshots`
- `@swap` mounted at `/.swapvol`

The swap subvolume is empty; no swapfile is configured.

## Test credentials

- Username: `test`
- Initial password: `test`

This is an isolated VM test configuration. Change the password before using it for anything beyond testing. Passwordless sudo is enabled for convenience and should not be used on a production machine.

## Notes

- The configuration targets x86_64 UEFI systems.
- The disk ID must be the whole-disk identifier, not a partition identifier.
- `system.stateVersion` is set to `26.05`; adjust it if installing a different NixOS release.
