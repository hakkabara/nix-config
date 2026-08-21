{ config, ... }:

let
  cfg = config.hakkabara.browsers.chromium.chromium;
in
{
  programs.chromium.enable = cfg.enable;
}
