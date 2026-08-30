{ lib, ... }:

{
  options.hakkabara.browsers.chromium = {
    chromium.enable = lib.mkEnableOption "Chromium reference/testing browser";
    googleChrome.enable = lib.mkEnableOption "Google Chrome browser";

    vivaldi.enable = lib.mkEnableOption "Vivaldi browser";
  };
}
