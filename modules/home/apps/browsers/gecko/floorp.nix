{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.browsers.gecko.floorp;
in
{
  home.packages = lib.optionals cfg.enable [
    pkgs.floorp-bin
  ];
}
