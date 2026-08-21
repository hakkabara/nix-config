{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.browsers.chromium.vivaldi;
in
{
  home.packages = lib.optionals cfg.enable [
    pkgs.vivaldi
  ];
}
