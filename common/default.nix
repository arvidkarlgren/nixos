{ pkgs, ... }:
{
  imports = [ ./users.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  environment.systemPackages = with pkgs; [ git ];

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

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
