{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.hakkabara.apps.signal.enable = lib.mkEnableOption "Signal Desktop messenger";

  config = lib.mkIf config.hakkabara.apps.signal.enable {
    home.packages = [
      pkgs.signal-desktop
    ];
  };
}
