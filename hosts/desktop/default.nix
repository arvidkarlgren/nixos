{
  imports = [
    ../../common
    ./hardware.nix
    ./disko.nix
    ./configuration.nix
  ];
  networking.hostName = "desktop";
  system.stateVersion = "26.05";
}
