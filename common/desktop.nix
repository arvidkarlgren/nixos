{ ... }:
{
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  console.keyMap = "sv-latin1";
  services.xserver.xkb.layout = "se";
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
}
