{ pkgs, ... }:
{
  imports = [ ./users.nix ];

  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  console.keyMap = "sv-latin1";
  services.xserver.xkb.layout = "se";
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    git
    firefox
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  sops.defaultSopsFile = ../secrets/common.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.secrets."passwords/arvid".neededForUsers = true;
  sops.secrets."ssh/arvid" = {
    path = "/home/arvid/.ssh/id_ed25519";
    owner = "arvid";
    group = "users";
    mode = "0600";
  };

  systemd.tmpfiles.rules = [
    "d /home/arvid/.ssh 0700 arvid users -"
  ];
}
