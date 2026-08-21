{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.browsers.gecko.extensions.darkReader;

  jsonFormat = pkgs.formats.json { };

  anyGeckoBrowserEnabled = config.programs.firefox.enable || config.programs.floorp.enable;
in
{
  options.hakkabara.browsers.gecko.extensions.darkReader.settings = {
    enable = lib.mkEnableOption "declarative Dark Reader settings";

    data = lib.mkOption {
      type = lib.types.attrs;
      default = { };

      description = ''
        Dark Reader configuration represented as native Nix data.

        Home Manager renders this into an importable Dark Reader
        JSON settings file.
      '';
    };
  };

  config = lib.mkIf (anyGeckoBrowserEnabled && cfg.enable && cfg.settings.enable) {
    xdg.configFile."hakkabara/browser-exports/dark-reader-settings.json".source =
      jsonFormat.generate "dark-reader-settings.json" cfg.settings.data;
  };
}
