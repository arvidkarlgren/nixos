{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../common/personal.nix
  ];

  networking.hostName = "t14s-nix";

  sops.secrets."ssh/arvid" = {
    sopsFile = ../../secrets/hosts/laptop.yaml;
    path = "/home/arvid/.ssh/id_ed25519";
    owner = "arvid";
    group = "users";
    mode = "0600";
  };

  system.stateVersion = "26.05";
}
