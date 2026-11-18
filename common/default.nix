{ pkgs, ... }:
{
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

  console.keyMap = "sv-latin1";
  services.xserver.xkb.layout = "se";
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_SE.UTF-8";

  environment.systemPackages = with pkgs; [
    git
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  sops.defaultSopsFile = ../secrets/common.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.sshKeyPaths = [ ];
  sops.gnupg.sshKeyPaths = [ ];
}
