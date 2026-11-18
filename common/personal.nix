{ config, lib, pkgs, ... }:
{
  imports = [
    ../modules/firefox.nix
    ../modules/kde.nix
    ../modules/plymouth.nix
    ../modules/windows-remote.nix
  ];

  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    authKeyFile = config.sops.secrets."tailscale/oauth".path;
    extraUpFlags = [
      "--advertise-tags=tag:personal"
      "--accept-routes"
      "--accept-dns"
      "--operator=arvid"
    ];
    extraSetFlags = [
      "--accept-routes"
      "--accept-dns"
      "--operator=arvid"
    ];
  };

  systemd.services.tailscaled-autoconnect = {
    serviceConfig = {
      RuntimeDirectory = "tailscale-auth";
      RuntimeDirectoryMode = "0700";
    };
    script = lib.mkForce ''
      set -euo pipefail
      key_file="$RUNTIME_DIRECTORY/auth-key"
      trap 'rm -f "$key_file"' EXIT

      while true; do
        state="$(tailscale status --json --peers=false | jq -r '.BackendState')"
        case "$state" in
          NeedsLogin|NeedsMachineAuth|Stopped)
            # Keep the OAuth secret out of the command line and use a persistent node.
            umask 077
            printf '%s?ephemeral=false' "$(cat ${config.sops.secrets."tailscale/oauth".path})" > "$key_file"
            tailscale up --auth-key="file:$key_file" ${lib.escapeShellArgs config.services.tailscale.extraUpFlags}
            rm -f "$key_file"
            ;;
          Running)
            systemd-notify --ready
            exit 0
            ;;
          *)
            echo "Waiting for Tailscale: $state"
            ;;
        esac
        sleep 1
      done
    '';
  };

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

  sops.secrets."tailscale/oauth" = {
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
