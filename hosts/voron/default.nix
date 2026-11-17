{ config, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  sdImage.compressImage = false;

  networking.hostName = "voron";
  networking.networkmanager.enable = true;

  users.users.arvid = {
    isNormalUser = true;
    home = "/home/arvid";
    createHome = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  hardware.enableRedistributableFirmware = true;
  nixpkgs.hostPlatform = "aarch64-linux";

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "sv-latin1";

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    settings.publish = {
      "disable-publishing" = false;
      "disable-user-service-publishing" = false;
      "publish-addresses" = true;
    };
  };

  services.klipper = {
    enable = true;
    mutableConfig = true;
    user = "moonraker";
    group = "moonraker";
    logFile = "/var/lib/klipper/logs/klippy.log";
    settings = {
      printer = {
        kinematics = "corexy";
        max_velocity = 100;
        max_accel = 1000;
        max_z_velocity = 10;
        max_z_accel = 100;
        square_corner_velocity = 5;
      };
      virtual_sdcard.path = "/var/lib/moonraker/gcodes";
      pause_resume = { };
      display_status = { };
      exclude_object = { };
    };
  };

  services.moonraker = {
    enable = true;
    allowSystemControl = true;
    settings = {
      authorization.trusted_clients = [
        "127.0.0.0/8"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];
      file_manager = {
        config_path = "/var/lib/klipper";
        log_path = "/var/lib/klipper/logs";
        gcode_path = "/var/lib/moonraker/gcodes";
      };
      "webcam Printer" = {
        location = "Printer";
        service = "mjpegstreamer";
        stream_url = "/webcam/?action=stream";
        snapshot_url = "/webcam/?action=snapshot";
      };
    };
  };

  services.mainsail = {
    enable = true;
    hostName = "voron.local";
    nginx = {
      default = true;
      serverAliases = [ "voron" ];
      locations."/webcam/" = {
        proxyPass = "http://127.0.0.1:5050/";
        extraConfig = "proxy_buffering off;";
      };
    };
  };

  services.mjpg-streamer.enable = true;
  security.polkit.enable = true;

  networking.firewall.allowedTCPPorts = [ 80 ];

  sops.defaultSopsFile = ../../secrets/common.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.secrets."passwords/arvid" = {
    sopsFile = ../../secrets/hosts/voron.yaml;
    neededForUsers = true;
  };
  users.users.arvid.hashedPasswordFile = config.sops.secrets."passwords/arvid".path;

  systemd.tmpfiles.rules = [
    "d /var/lib/klipper/logs 0775 moonraker moonraker -"
    "d /var/lib/moonraker/gcodes 0775 moonraker moonraker -"
  ];

  system.stateVersion = "26.05";
}
