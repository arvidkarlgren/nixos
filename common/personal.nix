{ config, lib, pkgs, ... }:
{
  imports = [
    ../modules/firefox.nix
    ../modules/kde.nix
    ../modules/plymouth.nix
    ../modules/windows-remote.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  i18n.defaultLocale = "en_SE.UTF-8";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  home-manager.users.arvid = { config, ... }: {
    xdg.configFile."OrcaSlicer/user".source =
      config.lib.file.mkOutOfStoreSymlink "/home/arvid/nixos/dotfiles/orcaslicer/user";

    programs.plasma.shortcuts."org.kde.dolphin.desktop"."_launch" = "Meta+F";
  };

  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];

  virtualisation.docker.enable = true;

  networking.networkmanager = {
    enable = true;
    ensureProfiles = {
      environmentFiles = [ config.sops.secrets."wifi/networkmanager".path ];
      profiles.Grannens_Wifi = import ../modules/wifi-profile.nix {
        id = "Grannens_Wifi";
        ssid = "$WIFI_SSID";
        psk = "$WIFI_PSK";
      };
    };
  };

  systemd.services.NetworkManager-ensure-profiles.restartTriggers = [
    config.sops.secrets."wifi/networkmanager".sopsFileHash
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
    audacity_3
    blender
    cifs-utils
    element-desktop
    freecad
    freetube
    libreoffice-qt6
    orca-slicer
    signal-desktop
    sops
    spotify
    (if lib.versionOlder trilium-desktop.version "0.107.0" then
      (trilium-desktop.override { electron_44 = electron_45; }).overrideAttrs (_: {
        version = "0.107.0";
        src = fetchurl {
          url = "https://github.com/TriliumNext/Trilium/releases/download/v0.107.0/TriliumNotes-v0.107.0-linux-x64.zip";
          hash = "sha256-pv6WquROAy8YJFLC7zmm/VZGIVO/FRvQu6ezvgaTebo=";
        };
      })
    else trilium-desktop)
    vscode
    xhost
  ];

  users.users.arvid = {
    isNormalUser = true;
    home = "/home/arvid";
    createHome = true;
    extraGroups = [ "wheel" "docker" ];
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

  sops.secrets."wifi/networkmanager" = {
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
    "d /home/arvid/git - arvid users -"
  ];
}
