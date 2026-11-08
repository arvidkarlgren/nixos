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

  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
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
}
