{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../common/personal.nix
  ];

  networking.hostName = "t1-nix";

  sops.secrets."ssh/arvid" = {
    sopsFile = ../../secrets/hosts/desktop.yaml;
    path = "/home/arvid/.ssh/id_ed25519";
    owner = "arvid";
    group = "users";
    mode = "0600";
  };

  system.stateVersion = "26.05";
}
