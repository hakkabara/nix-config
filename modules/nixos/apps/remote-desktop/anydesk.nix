{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.remoteDesktop.anydesk;
in
{
  options.hakkabara.apps.remoteDesktop.anydesk.enable =
    lib.mkEnableOption "AnyDesk remote desktop client";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.anydesk
    ];
  };
}
