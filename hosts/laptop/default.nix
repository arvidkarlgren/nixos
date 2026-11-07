{
  imports = [
    ../../common
    ./hardware.nix
    ./disko.nix
    ./configuration.nix
  ];
  networking.hostName = "laptop";
  system.stateVersion = "26.05";
}
