{ config, pkgs, ... }:
{
  imports = [
    ../modules/kde.nix
    ../modules/windows-remote.nix
  ];

  services.tailscale.enable = true;

  fileSystems."/mnt/files" = {
    device = "//nas1.kv.internal/files";
    fsType = "cifs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60s"
      "x-systemd.mount-timeout=10s"
      "credentials=${config.sops.secrets."smb/credentials".path}"
      "uid=arvid"
      "gid=users"
      "forceuid"
      "forcegid"
      "dir_mode=0770"
      "file_mode=0660"
      "soft"
    ];
  };

  environment.systemPackages = with pkgs; [
    alacritty
    cifs-utils
    firefox
    signal-desktop
    sops
    spotify
    vscode
  ];

  users.users.arvid = {
    isNormalUser = true;
    home = "/home/arvid";
    createHome = true;
    extraGroups = [ "wheel" ];
  };

  sops.secrets."passwords/arvid" = {
    sopsFile = ../secrets/personal.yaml;
    neededForUsers = true;
  };
  users.users.arvid.hashedPasswordFile = config.sops.secrets."passwords/arvid".path;

  sops.secrets."smb/credentials" = {
    sopsFile = ../secrets/personal.yaml;
    mode = "0400";
  };

  sops.secrets."age/personal" = {
    sopsFile = ../secrets/personal.yaml;
    path = "/home/arvid/.config/sops/age/keys.txt";
    owner = "arvid";
    group = "users";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /home/arvid/.config/sops/age 0700 arvid users -"
    "d /home/arvid/.ssh 0700 arvid users -"
  ];
}
