{ ... }:
let
  addon = slug: {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
  };
  toolbarAddon = slug: (addon slug) // { default_area = "navbar"; };
in
{
  programs.firefox = {
    enable = true;
    policies = {
      DisableFirefoxAccounts = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = toolbarAddon "ublock-origin";
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = toolbarAddon "bitwarden-password-manager";
        "{1ba6c5ad-4144-4f55-a9d6-55d58b4c0503}" = addon "ftblack";
      };
    };
    wrapperConfig.extraPrefs = ''
      lockPref("toolkit.telemetry.enabled", false);
      lockPref("toolkit.telemetry.unified", false);
      lockPref("toolkit.telemetry.bhrPing.enabled", false);
      lockPref("toolkit.telemetry.firstShutdownPing.enabled", false);
      lockPref("toolkit.telemetry.newProfilePing.enabled", false);
      lockPref("toolkit.telemetry.shutdownPingSender.enabled", false);
      lockPref("toolkit.telemetry.updatePing.enabled", false);
      lockPref("breakpad.reportURL", "");
      lockPref("app.shield.optoutstudies.enabled", false);
      lockPref("app.normandy.enabled", false);
    '';
    preferencesStatus = "user";
    preferences = {
      "sidebar.revamp" = true;
      "sidebar.verticalTabs" = true;
      "sidebar.new-sidebar.has-used" = true;
      "sidebar.main.tools" = "";
      "sidebar.installed.extensions" = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
      "sidebar.newTool.migration.passwords" = builtins.toJSON {
        visibilityPref = "browser.contextual-password-manager.enabled";
        alreadyShown = true;
      };
      "sidebar.newTool.migration.resourcemonitor" = builtins.toJSON {
        visibilityPref = "browser.resourceMonitor.enabled";
        alreadyShown = true;
      };
      "sidebar.newTool.migration.widgets" = builtins.toJSON {
        visibilityPref = "browser.widgets.generated.enabled";
        alreadyShown = true;
      };
      "browser.uidensity" = 1;
      "browser.compactmode.show" = true;
      "browser.toolbars.bookmarks.visibility" = "never";
      "browser.newtabpage.enabled" = true;
      "browser.newtabpage.activity-stream.showSearch" = true;
      "browser.newtabpage.activity-stream.hideLogo" = false;
      "browser.newtabpage.activity-stream.feeds.topsites" = false;
      "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
      "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
      "browser.newtabpage.activity-stream.showSponsored" = false;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      "browser.newtabpage.activity-stream.showWeather" = false;
      "browser.newtabpage.activity-stream.widgets.enabled" = false;
      "browser.newtabpage.activity-stream.widgets.system.enabled" = false;
      "browser.newtabpage.activity-stream.telemetry" = false;
      "browser.newtabpage.activity-stream.feeds.telemetry" = false;
      "browser.ping-centre.telemetry" = false;
      "browser.urlbar.quicksuggest.enabled" = false;
      "browser.urlbar.suggest.quicksuggest.sponsored" = false;
      "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
      "browser.tabs.crashReporting.sendReport" = false;
      "browser.discovery.enabled" = false;
    };
  };
}
