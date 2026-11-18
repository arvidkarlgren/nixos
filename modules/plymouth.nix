{ pkgs, ... }:
let
  progressBar = pkgs.writeText "plymouth-progress-bar.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="240" height="4">
      <rect width="240" height="4" fill="white"/>
    </svg>
  '';
  theme = pkgs.runCommand "plymouth-nixos-simple" {
    nativeBuildInputs = [ pkgs.librsvg ];
  } ''
    themeDir="$out/share/plymouth/themes/nixos-simple"
    mkdir -p "$themeDir"
    cp ${pkgs.nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png "$themeDir/logo.png"
    cp ${./plymouth.script} "$themeDir/nixos-simple.script"
    rsvg-convert ${progressBar} -o "$themeDir/progress.png"
    cat > "$themeDir/nixos-simple.plymouth" <<EOF
    [Plymouth Theme]
    Name=NixOS Simple
    Description=Static NixOS logo with a progress bar
    ModuleName=script

    [script]
    ImageDir=$themeDir
    ScriptFile=$themeDir/nixos-simple.script
    EOF
  '';
in
{
  boot.plymouth = {
    enable = true;
    theme = "nixos-simple";
    themePackages = [ theme ];
  };
}
