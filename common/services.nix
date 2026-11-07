{ ... }:
{
  # Currently shared by both hosts. Move to a host's configuration.nix
  # if you later want this service on only one machine.
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  hardware.uinput.enable = true;
}
