{ config, pkgs, ... }:
{
  imports = [ ../modules/kde.nix ];

  services.flatpak.enable = true;
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

  system.activationScripts.installVSCodeFlatpak = ''
    ${pkgs.flatpak}/bin/flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    if ! ${pkgs.flatpak}/bin/flatpak info --system com.visualstudio.code >/dev/null 2>&1; then
      ${pkgs.flatpak}/bin/flatpak install --system --noninteractive flathub com.visualstudio.code
    fi
  '';

  environment.systemPackages = with pkgs; [
    cifs-utils
    firefox
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
