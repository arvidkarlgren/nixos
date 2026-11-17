{ config, pkgs, ... }:
let
  windowsRemote = pkgs.writeShellScript "windows-remote" ''
    if ! server="$(< ${config.sops.secrets."rdp/windows/server".path})" ||
       ! username="$(< ${config.sops.secrets."rdp/windows/username".path})" ||
       ! password="$(< ${config.sops.secrets."rdp/windows/password".path})" ||
       [ -z "$server" ] || [ -z "$username" ] || [ -z "$password" ]; then
      ${pkgs.kdePackages.kdialog}/bin/kdialog --error "The Windows VM server, username, or password is missing or unreadable."
      exit 1
    fi
    if [[ "$server" == *$'\n'* || "$username" == *$'\n'* || "$password" == *$'\n'* ]]; then
      ${pkgs.kdePackages.kdialog}/bin/kdialog --error "The Windows VM server, username, and password must each be a single line."
      exit 1
    fi

    if ! printf '%s\n' \
      "/v:$server" "/u:$username" '/d:' "/p:$password" \
      '/f' '-grab-keyboard' '/gfx:AVC444' '/rfx-mode:video' \
      '/network:auto' '/dynamic-resolution' '+clipboard' \
      '/sound:sys:pulse' '/cert:ignore' |
      ${pkgs.freerdp}/bin/xfreerdp /args-from:stdin; then
      ${pkgs.kdePackages.kdialog}/bin/kdialog --error "Could not connect to the Windows VM."
      exit 1
    fi
  '';
in
{
  environment.systemPackages = [
    (pkgs.makeDesktopItem {
      name = "windows-remote";
      desktopName = "Windows 11 VM";
      comment = "Connect to Windows VM on Proxmox";
      exec = "${windowsRemote}";
      icon = "preferences-system-network";
      categories = [ "Network" "RemoteAccess" ];
      startupNotify = true;
    })
  ];

  sops.secrets = builtins.listToAttrs (map (key: {
    name = "rdp/windows/${key}";
    value = {
      sopsFile = ../secrets/personal.yaml;
      owner = "arvid";
      group = "users";
      mode = "0400";
    };
  }) [ "server" "username" "password" ]);
}
