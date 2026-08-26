{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.apps.steam;
in
{
  options.hakkabara.apps.steam.enable = lib.mkEnableOption "Steam gaming client";

  config = lib.mkIf cfg.enable {
    programs.steam.enable = true;
  };
}
