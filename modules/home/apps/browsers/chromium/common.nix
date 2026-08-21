{ lib, ... }:

{
  options.hakkabara.browsers.chromium = {
    chromium.enable = lib.mkEnableOption "Chromium reference/testing browser";

    vivaldi.enable = lib.mkEnableOption "Vivaldi browser";
  };
}
