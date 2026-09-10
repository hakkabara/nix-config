{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.helpers.pihole;
in
{
  options.hakkabara.helpers.pihole.enable = lib.mkEnableOption "Pi-hole helper tools";

  config = lib.mkIf cfg.enable {

    home.packages = [
      pkgs.curl
      pkgs.jq
    ];

    home.file.".local/bin/pihole" = {
      source = ./scripts/pihole;
      executable = true;
    };

  };
}
