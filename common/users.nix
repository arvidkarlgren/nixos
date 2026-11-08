{ ... }:
{
  users.users.arvid = {
    isNormalUser = true;
    home = "/home/arvid";
    createHome = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = "/var/lib/nixos/arvid-password";
  };
}
