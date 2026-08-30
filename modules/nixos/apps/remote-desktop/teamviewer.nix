{
  config,
  lib,
  pkgsUnstableUnfree,
  ...
}:

let
  cfg = config.hakkabara.apps.remoteDesktop.teamviewer;
in
{
  options.hakkabara.apps.remoteDesktop.teamviewer.enable =
    lib.mkEnableOption "TeamViewer remote desktop client";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgsUnstableUnfree.teamviewer
    ];

    # Intentionally package-only:
    # no services.teamviewer.enable and therefore no persistent teamviewerd.
  };
}
