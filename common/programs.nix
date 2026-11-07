{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git neovim wget curl htop ripgrep fd unzip
  ];
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
