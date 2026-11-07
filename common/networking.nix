{ ... }:
{
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowPing = false;
  };
  services.openssh = {
    enable = true;
    openFirewall = true;
  };
}
