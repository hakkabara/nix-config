{ config, lib, pkgs, ... }:

let
  cfg = config.hakkabara.apps.pihole;
in
{
  options.hakkabara.apps.pihole.enable =
    lib.mkEnableOption "Pi-hole helper tools";

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
