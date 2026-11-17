{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../common/personal.nix
    ../../modules/steam.nix
  ];

  networking.hostName = "t1-nix";

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
