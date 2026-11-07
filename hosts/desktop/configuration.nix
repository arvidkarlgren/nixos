{ config, pkgs, ... }:

{
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

  networking.hostName = "desktop";
  networking.networkmanager.enable = true;

  services.openssh.enable = true;

  # COSMIC desktop
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  users.users.arvid = {
    isNormalUser = true;
    home = "/home/arvid";
    createHome = true;
    extraGroups = [ "wheel" ];
    initialPassword = "test";
  };

  # Passwordless sudo: VM testing only
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
  ];

  # xrdp provides a separate X11 session; it does not share the
  # active COSMIC Wayland session.
  services.xrdp = {
    enable = true;
    openFirewall = true;
  };

  # Clone the configuration repository on activation if it is absent.
  system.activationScripts.cloneNixosConfig = {
    deps = [ "users" ];
    text = ''
      if [ ! -d /home/arvid/nixos/.git ]; then
        ${pkgs.util-linux}/bin/runuser -u arvid --           ${pkgs.git}/bin/git clone           https://github.com/arvidkarlgren/nixos.git           /home/arvid/nixos
      fi
    '';
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  console.keyMap = "sv-latin1";
  services.xserver.xkb.layout = "se";

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "26.05";
}
