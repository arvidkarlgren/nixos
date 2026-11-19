{ pkgs, ... }:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../common/personal.nix
    ../../modules/steam.nix
  ];

  networking.hostName = "t1-nix";

  boot.initrd.kernelModules = [ "amdgpu" ];

  systemd.services.sync-sddm-displays = {
    description = "Synchronize Plasma display settings to SDDM";
    wantedBy = [ "multi-user.target" "display-manager.service" ];
    before = [ "display-manager.service" ];
    unitConfig.RequiresMountsFor = [ "/home/arvid" "/var/lib/sddm" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      source=/home/arvid/.config/kwinoutputconfig.json
      target=/var/lib/sddm/.config/kwinoutputconfig.json

      if [ ! -e "$source" ]; then
        echo "Plasma display settings not found at $source; keeping existing SDDM settings" >&2
        exit 0
      fi

      tmp="$(${pkgs.coreutils}/bin/mktemp /var/lib/sddm/.config/.kwinoutputconfig.XXXXXX)"
      trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
      ${pkgs.util-linux}/bin/runuser -u arvid -- \
        ${pkgs.jq}/bin/jq -e 'if type == "array" then . else error("Invalid KWin output configuration") end' \
        "$source" > "$tmp"
      ${pkgs.coreutils}/bin/chown sddm:sddm "$tmp"
      ${pkgs.coreutils}/bin/chmod 600 "$tmp"
      ${pkgs.coreutils}/bin/mv -f "$tmp" "$target"
    '';
  };

  systemd.paths.sync-sddm-displays = {
    description = "Watch Plasma display settings for SDDM";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = "/home/arvid/.config/kwinoutputconfig.json";
  };

  fileSystems."/home/arvid/games" = {
    device = "/dev/disk/by-uuid/6a87ec41-e917-4ba0-8658-6145d294ce06";
    fsType = "btrfs";
    options = [ "subvol=games" ];
  };

  hardware.xone.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c547", TEST=="power/wakeup", ATTR{power/wakeup}="disabled"
  '';

  environment.shellAliases.rebuild = "sudo nixos-rebuild switch --flake /home/arvid/nixos#desktop";
  environment.shellAliases.displays = "/home/arvid/nixos/scripts/displays.sh";

  personal.kde.displaySwitchHotkeys.enable = true;

  sops.secrets."ssh/arvid" = {
    sopsFile = ../../secrets/hosts/desktop.yaml;
    path = "/home/arvid/.ssh/id_ed25519";
    owner = "arvid";
    group = "users";
    mode = "0600";
  };

  system.stateVersion = "26.05";
}
