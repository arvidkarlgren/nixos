{ ... }:
{
  users.users.arvid = {
    isNormalUser = true;
    home = "/home/arvid";
    createHome = true;
    extraGroups = [ "wheel" "networkmanager" "uinput" ];
    # Temporary testing password. Replace with a SOPS-managed hash.
    initialPassword = "test";
  };

  # Testing convenience only; review before daily use.
  security.sudo.wheelNeedsPassword = false;
}
