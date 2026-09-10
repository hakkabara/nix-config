{ config, ... }:

let
  cfg = config.hakkabara.browsers.chromium.googleChrome;
in
{
  programs.google-chrome.enable = cfg.enable;
}
