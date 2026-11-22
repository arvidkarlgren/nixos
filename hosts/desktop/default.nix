{ config, lib, pkgs, ... }:
let
  homeAssistantWebhook = pkgs.writeShellApplication {
    name = "home-assistant-webhook";
    runtimeInputs = [ pkgs.curl pkgs.libnotify ];
    text = ''
      if ! curl --config "$1" --proto '=https' --request POST --fail --silent \
        --output /dev/null --max-time 10; then
        notify-send --urgency=critical "Home Assistant" "Webhook request failed."
        exit 1
      fi
    '';
  };
in
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../common/personal.nix
    ../../modules/steam.nix
  ];

  environment.systemPackages = [
    pkgs.cemu
    (pkgs.makeDesktopItem {
      name = "info.cemu.Cemu";
      desktopName = "Cemu";
      genericName = "Wii U Emulator";
      comment = "Play Wii U games";
      exec = "${pkgs.lib.getExe pkgs.cemu}";
      icon = "info.cemu.Cemu";
      categories = [ "Game" "Emulator" ];
    })
    (pkgs.symlinkJoin {
      name = "prismlauncher-configured";
      paths = [ pkgs.prismlauncher ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        rm "$out/bin/prismlauncher"
        makeWrapper ${pkgs.lib.getExe pkgs.prismlauncher} "$out/bin/prismlauncher" \
          --add-flags "--dir /home/arvid/games/prismlauncher"
      '';
    })
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

  sops.secrets = lib.genAttrs [
    "home-assistant/home"
    "home-assistant/page-up"
    "home-assistant/page-down"
  ] (_: {
    sopsFile = ../../secrets/hosts/desktop.yaml;
    owner = "arvid";
    mode = "0400";
  }) // {
    "ssh/arvid" = {
      sopsFile = ../../secrets/hosts/desktop.yaml;
      path = "/home/arvid/.ssh/id_ed25519";
      owner = "arvid";
      group = "users";
      mode = "0600";
    };
  };

  home-manager.users.arvid.programs.plasma.hotkeys.commands = {
    home-assistant-home = {
      name = "Home Assistant Home";
      key = "Meta+Shift+Home";
      command = "${lib.getExe homeAssistantWebhook} ${config.sops.secrets."home-assistant/home".path}";
    };
    home-assistant-page-up = {
      name = "Home Assistant Page Up";
      key = "Meta+Shift+PgUp";
      command = "${lib.getExe homeAssistantWebhook} ${config.sops.secrets."home-assistant/page-up".path}";
    };
    home-assistant-page-down = {
      name = "Home Assistant Page Down";
      key = "Meta+Shift+PgDown";
      command = "${lib.getExe homeAssistantWebhook} ${config.sops.secrets."home-assistant/page-down".path}";
    };
  };

  system.stateVersion = "26.05";
}
