{ config, lib, pkgs, ... }:
let
  wallpaper = ../wallpapers/tyler-lastovich-ddLiNMqWAOM-unsplash.jpg;
in
{
  options.personal.kde.displaySwitchHotkeys.enable =
    lib.mkEnableOption "desktop display switching shortcuts";

  config.services.desktopManager.plasma6.enable = true;
  config.services.displayManager.sddm.enable = true;
  config.services.displayManager.sddm.theme = "breeze";
  config.environment.systemPackages = [
    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=${wallpaper}
    '')
  ];
  config.systemd.tmpfiles.rules = [
    "d /var/lib/sddm/.config 0755 sddm sddm -"
    "L+ /var/lib/sddm/.config/kdeglobals - - - - ${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors"
  ];
  config.hardware.graphics.enable = true;
  config.hardware.graphics.enable32Bit = true;
  config.hardware.bluetooth.enable = true;
  config.environment.plasma6.excludePackages = [ pkgs.kdePackages.konsole ];

  config.home-manager.users.arvid =
    { lib, ... }:
    {
      home.stateVersion = "26.05";

      xdg.dataFile."kwin/scripts/move-and-follow/metadata.json".text = builtins.toJSON {
        KPackageStructure = "KWin/Script";
        KPlugin = {
          Id = "move-and-follow";
          Name = "Move window and follow";
        };
        X-Plasma-API = "javascript";
        X-Plasma-MainScript = "code/main.js";
      };

      xdg.dataFile."kwin/scripts/move-and-follow/contents/code/main.js".text = ''
        for (let number = 1; number <= 10; number++) {
          registerShortcut(
            `Move and follow to desktop ''${number}`,
            `Move window and follow to desktop ''${number}`,
            "",
            () => {
              const window = workspace.activeWindow;
              const desktop = workspace.desktops[number - 1];
              if (!window) {
                return;
              }
              if (!desktop) {
                console.warn(`Cannot move window: desktop ''${number} does not exist`);
                return;
              }

              const output = window.output;
              window.desktops = [desktop];
              workspace.setCurrentDesktopForScreen(desktop, output);
              workspace.activeWindow = window;
            }
          );
        }
      '';

      programs.plasma = {
        enable = true;

        workspace = {
          colorScheme = "BreezeDark";
          lookAndFeel = "org.kde.breezedark.desktop";
          wallpaper = "${wallpaper}";
          wallpaperFillMode = "preserveAspectCrop";
        };

        kscreenlocker.appearance.wallpaper = "${wallpaper}";

        session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

        panels = [
          {
            height = 36;
            floating = true;
            widgets = [
              { kickoff.icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg"; }
              { iconTasks.launchers = [ ]; }
              "org.kde.plasma.marginsseparator"
              {
                systemTray.items.hidden = [
                  "org.kde.merkuro.contact.applet"
                  "org.kde.plasma.clipboard"
                  "org.kde.plasma.brightness"
                ];
              }
              { digitalClock.date.enable = false; }
              "org.kde.plasma.showdesktop"
            ];
          }
        ];

        shortcuts = {
          kwin = (builtins.listToAttrs (
            map (n: {
              name = "Switch to Desktop ${toString n}";
              value = "Meta+${if n == 10 then "0" else toString n}";
            }) (lib.range 1 10)
          )) // (builtins.listToAttrs (
            map (n: {
              name = "Window to Desktop ${toString n}";
              value = [ ];
            }) (lib.range 1 10)
          )) // (builtins.listToAttrs (
            # KDE matches the shifted symbol on the Swedish layout (Shift+1 = "!")
            map (n: {
              name = "Move and follow to desktop ${toString n}";
              value = [
                "Meta+Shift+${if n == 10 then "0" else toString n}"
                "Meta+${builtins.elemAt [ "!" "\"" "#" "¤" "%" "&" "/" "(" ")" "=" ] (n - 1)}"
              ];
            }) (lib.range 1 10)
          )) // {
            "Window Close" = [ "Alt+F4" "Meta+Q" ];
            "Window Maximize" = [ "Meta+PgUp" "Meta+M" ];
            "Window Minimize" = [ "Meta+PgDown" "Alt+Esc" ];
            "Edit Tiles" = [ ];
            view_actual_size = [ ];
          };
          plasmashell = builtins.listToAttrs (
            map (n: {
              name = "activate task manager entry ${toString n}";
              value = [ ];
            }) (lib.range 1 9)
          ) // {
            "manage activities" = [ ];
          };
          org_kde_powerdevil.Sleep = [ "Sleep" "Meta+Esc" ];
          "org.kde.konsole.desktop"."_launch" = [ ];
          "Alacritty.desktop"."_launch" = "Meta+T";
          "org.kde.plasma-systemmonitor.desktop"."_launch" = [ ];
        };

        hotkeys.commands = lib.mkIf config.personal.kde.displaySwitchHotkeys.enable {
          display-desk = {
            name = "Desk displays";
            key = "Meta+F1";
            command = "/home/arvid/nixos/scripts/displays.sh desk";
          };
          display-tv = {
            name = "TV display";
            key = "Meta+F2";
            command = "/home/arvid/nixos/scripts/displays.sh tv";
          };
        };

        configFile."kwinrc".Desktops.Number = 10;
        configFile."kwinrc".Windows.PerOutputVirtualDesktops = true;
        configFile."kwinrc".EdgeBarrier.EdgeBarrier = 0;
        configFile."kwinrc".ElectricBorders = {
          TopLeft = "None";
          TopRight = "None";
          BottomLeft = "None";
          BottomRight = "None";
        };
        configFile."kwinrc".Plugins."move-and-followEnabled" = true;

        configFile."plasma-localerc".Formats = {
          LANG = "en_SE.UTF-8";
          LC_TIME = "en_SE.UTF-8";
        };

        configFile."kdeglobals".Sounds.Enable = false;
        configFile."kdeglobals".KDE.AnimationDurationFactor = 0.5;
        configFile."plasmaparc".General.AudioFeedback = false;

        configFile."kdeglobals".General = {
          TerminalApplication = "alacritty";
          TerminalService = "Alacritty.desktop";
        };

        configFile."kcminputrc"."Libinput/1133/50503/Logitech USB Receiver".PointerAcceleration = 0.25;

        # Per-device overrides in ~/.config/kcminputrc take precedence over these defaults.
        configFile."kcminputrc"."Libinput/Defaults/Pointer".PointerAccelerationProfile = 1;
      };
    };
}
