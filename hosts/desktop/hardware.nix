{ ... }:
{
  # Proxmox VM starter settings. Extend with:
  # nixos-generate-config --show-hardware-config
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_scsi" "ahci" "sd_mod"
  ];
}
