{ config, ... }:
{
  users.users.arvid = {
    isNormalUser = true;
    home = "/home/arvid";
    createHome = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets."passwords/arvid".path;
  };
}
