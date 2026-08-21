{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.browsers.gecko;

  mkExtensionOption =
    description:
    lib.mkOption {
      type = lib.types.bool;
      default = false;
      inherit description;
    };

  firefoxBookmarks = pkgs.writeShellApplication {
    name = "fbm";

    runtimeInputs = [
      pkgs.sops
      pkgs.python3
    ];

    text = ''
      exec python3 ${../scripts/firefox-bookmarks.py} "$@"
    '';
  };
in
{
  options.hakkabara.browsers.gecko = {
    firefox.enable = lib.mkEnableOption "Firefox";
    floorp.enable = lib.mkEnableOption "Floorp";

    extensions = {
      uBlockOrigin.enable = mkExtensionOption "uBlock Origin";

      darkReader.enable = mkExtensionOption "Dark Reader";

      bitwarden.enable = mkExtensionOption "Bitwarden browser extension";

      multiAccountContainers.enable = mkExtensionOption "Firefox Multi-Account Containers";

      consentOMatic.enable = mkExtensionOption "Consent-O-Matic";

      sponsorBlock.enable = mkExtensionOption "SponsorBlock";

      enhancerForYouTube.enable = mkExtensionOption "Enhancer for YouTube";
    };
  };

  # fbm is useful to the Gecko browser family, not Firefox specifically.
  #
  # This also prepares us to let Floorp use the same encrypted bookmark
  # source later without duplicating the helper.
  config = lib.mkIf (cfg.firefox.enable || cfg.floorp.enable) {
    home.packages = [
      firefoxBookmarks
    ];
  };
}
