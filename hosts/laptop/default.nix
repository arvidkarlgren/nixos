{
  imports = [
    ./disko.nix
    ./hardware.nix
  ];

  networking.hostName = "t14s-nix";
  system.stateVersion = "26.05";
}
