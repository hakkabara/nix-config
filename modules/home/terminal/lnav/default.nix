{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.terminal;
in
{
  config = lib.mkIf (cfg.enable && cfg.lnav.enable) {
    home.packages = [
      pkgs.lnav
      pkgs.xclip
    ];

    xdg.configFile = {
      "lnav/config.json".text = builtins.toJSON {
        "$schema" = "https://lnav.org/schemas/config-v1.schema.json";

        ui = {
          "clock-format" = "%Y-%m-%d %H:%M:%S";
          "default-colors" = true;
          "dim-text" = false;
        };
      };

      # External formats must be exactly one directory below formats/
      # because lnav scans:
      #
      #   <lnav-home>/formats/*/*.json
      #
      "lnav/formats/paulway" = {
        source = ./formats/vendor/paulway;
        recursive = true;
      };

      "lnav/formats/xenserver" = {
        source = ./formats/vendor/xenserver;
        recursive = true;
      };

      # Our own future generic formats.
      #
      # JSON format files must be placed directly in this directory.
      # If we later want groups such as firewall/network/dfir, we will expose
      # each group as its own directory directly below lnav/formats/.
      "lnav/formats/custom" = {
        source = ./formats/custom;
        recursive = true;
      };
    };
  };
}
