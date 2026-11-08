{
  imports = [
    ./disko.nix
    ./hardware.nix
  ];

  networking.hostName = "t1-nix";
  system.stateVersion = "26.05";
}
