{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.apps.remoteDesktop.rustdesk;
in
{
  options.hakkabara.apps.remoteDesktop.rustdesk.enable =
    lib.mkEnableOption "RustDesk remote desktop client via Flatpak";

  config = lib.mkIf cfg.enable {
    services.flatpak.packages = [
      "com.rustdesk.RustDesk"
    ];
  };
}
