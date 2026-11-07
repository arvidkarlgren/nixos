{ config, pkgs, ... }:

{
  # Bootloader: Proxmox OVMF / UEFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Proxmox virtual hardware
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "ahci"
    "sd_mod"
  ];

  # Networking
  networking.hostName = "desktop";
  networking.networkmanager.enable = true;

  # SSH
  services.openssh.enable = true;

  # COSMIC desktop
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # Graphics
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # Test user: change this password after installation.
  users.users.test = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "test";
  };

  # Passwordless sudo: VM testing only.
  security.sudo.wheelNeedsPassword = false;

  # Flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";

  # Set to the release used for this initial installation.
  system.stateVersion = "26.05";
}
