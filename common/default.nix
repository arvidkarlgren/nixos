{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

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
  environment.systemPackages = with pkgs; [
    git
    gdu
    htop
    sshfs
  ];

  sops.defaultSopsFile = ../secrets/common.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.sshKeyPaths = [ ];
  sops.gnupg.sshKeyPaths = [ ];
}
