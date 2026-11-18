{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../common/personal.nix
    ../../modules/steam.nix
  ];

  networking.hostName = "t1-nix";

  boot.initrd.kernelModules = [ "amdgpu" ];

  fileSystems."/home/arvid/games" = {
    device = "/dev/disk/by-uuid/6a87ec41-e917-4ba0-8658-6145d294ce06";
    fsType = "btrfs";
    options = [ "subvol=games" ];
  };

  hardware.xone.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c547", TEST=="power/wakeup", ATTR{power/wakeup}="disabled"
  '';

  environment.shellAliases.rebuild = "sudo nixos-rebuild switch --flake /home/arvid/nixos#desktop";
  environment.shellAliases.displays = "/home/arvid/nixos/scripts/displays.sh";

  personal.kde.displaySwitchHotkeys.enable = true;

  sops.secrets."ssh/arvid" = {
    sopsFile = ../../secrets/hosts/desktop.yaml;
    path = "/home/arvid/.ssh/id_ed25519";
    owner = "arvid";
    group = "users";
    mode = "0600";
  };

  system.stateVersion = "26.05";
}
