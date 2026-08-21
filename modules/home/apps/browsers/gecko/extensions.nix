{ lib, cfg }:

(lib.optionalAttrs cfg.uBlockOrigin.enable {
  "uBlock0@raymondhill.net" = {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
    default_area = "navbar";
    private_browsing = true;
  };
})
// (lib.optionalAttrs cfg.darkReader.enable {
  "addon@darkreader.org" = {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
    default_area = "navbar";
    private_browsing = true;
  };
})
// (lib.optionalAttrs cfg.bitwarden.enable {
  "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
    default_area = "navbar";
    private_browsing = true;
  };
})
// (lib.optionalAttrs cfg.multiAccountContainers.enable {
  "@testpilot-containers" = {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi";
    default_area = "menupanel";
  };
})
// (lib.optionalAttrs cfg.consentOMatic.enable {
  "gdpr@cavi.au.dk" = {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
    default_area = "menupanel";
  };
})
// (lib.optionalAttrs cfg.sponsorBlock.enable {
  "sponsorBlocker@ajay.app" = {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
    default_area = "menupanel";
  };
})
// (lib.optionalAttrs cfg.enhancerForYouTube.enable {
  "enhancerforyoutube@maximerf.addons.mozilla.org" = {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/enhancer-for-youtube/latest.xpi";
    default_area = "menupanel";
  };
})
